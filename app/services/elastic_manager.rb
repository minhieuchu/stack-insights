require "singleton"

IndexSettings = Struct.new(:index_name, :mapping_file)

class ElasticManager
  include Singleton
  include Utils

  def initialize
    @index_settings = [
      IndexSettings.new(QUESTION_INDEX, "question.json"),
      IndexSettings.new(COMMENT_INDEX, "comment.json"),
      IndexSettings.new(BADGE_INDEX, "badge.json"),
      IndexSettings.new(USER_INDEX, "user.json"),
      IndexSettings.new(TAG_INDEX, "tag.json"),
    ]
  end

  def create_indices
    @index_settings.each do |index_setting|
      index_mappings = JSON.parse(File.read(File.join(File.dirname(__FILE__), "/elastic_indices/#{index_setting.mapping_file}")))

      unless ElasticClient.indices.exists?(index: index_setting.index_name)
        ElasticClient.indices.create(index: index_setting.index_name, body: index_mappings)
      end
    end
  end

  def reset_indices
    @index_settings.each do |index_setting|
      ElasticClient.indices.delete(index: index_setting.index_name)
    end
    create_indices
  end

  def refined_attr_value(attr_value)
    if ["True", "False"].include?(attr_value)
      return camel_to_snake(attr_value)
    end
    attr_value
  end

  def process_posts_xml
    post_file_path = File.join(File.dirname(__FILE__), "/elastic_documents/Posts.xml")
    question_bulk = []
    question_bulk_size = 0

    File.foreach(post_file_path) do |line|
      xml_object = Nokogiri::XML(line)
      row_element = xml_object.at_xpath("//row")
      unless row_element.nil?
        post = POST_ATTRIBUTES.each_with_object({}) do |attr_name, document|
          unless row_element.attr(attr_name).nil?
            document[camel_to_snake(attr_name)] = refined_attr_value(row_element.attr(attr_name))
          end
        end

        if post["post_type_id"] == "1"
          post["answers"] = []
          question_bulk << post
          question_bulk_size += post.to_json.bytesize
        elsif post["post_type_id"] == "2"
          related_question = question_bulk.find { |question| question["id"] == post["parent_id"] }
          unless related_question.nil?
            related_question["answers"] << post
            question_bulk_size += post.to_json.bytesize
          else
            ElasticClient.update_by_query(
              index: QUESTION_INDEX,
              body: {
                query: { match: { id: post["parent_id"] } },
                script: {
                  source: "ctx._source.answers.add(params.answer)",
                  params: {
                    answer: post,
                  },
                },
              },
              refresh: "true",
            )
          end
        end

        if question_bulk_size >= MAX_BULK_SIZE
          question_bulk_body = question_bulk.map do |question|
            [
              { index: { _index: QUESTION_INDEX } },
              question,
            ]
          end.flatten

          ElasticClient.bulk(
            body: question_bulk_body,
            refresh: "true",
          )
          question_bulk = []
          question_bulk_size = 0
        end
      end
    end

    if question_bulk.length > 0
      question_bulk_body = question_bulk.map do |question|
        [
          { index: { _index: QUESTION_INDEX } },
          question,
        ]
      end.flatten
      ElasticClient.bulk(
        body: question_bulk_body,
        refresh: "true",
      )
    end
  end

  def search_questions(keywords)
    response = ElasticClient.search(
      index: QUESTION_INDEX,
      body: {
        query: {
          bool: {
            should: [
              { match: { title: keywords } },
              { match: { body: keywords } },
              { match: { tags: keywords } },
            ],
            must: {
              term: {
                post_type_id: "1",
              },
            },
            minimum_should_match: 1,
          },
        },
      },
    )
    results = response.dig("hits", "hits").map { |document| document.dig("_source") }
  end
end
