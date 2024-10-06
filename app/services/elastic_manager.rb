require "singleton"

IndexSettings = Struct.new(:index_name, :index_attributes, :mapping_file, :data_file)

class ElasticManager
  include Singleton
  include Utils

  def initialize
    @index_settings = [
      IndexSettings.new(QUESTION_INDEX, POST_ATTRIBUTES, "question.json", "Posts.xml"),
      IndexSettings.new(USER_INDEX, USER_ATTRIBUTES, "user.json", "Users.xml"),
      IndexSettings.new(COMMENT_INDEX, COMMENT_ATTRIBUTES, "comment.json", "Comments.xml"),
      IndexSettings.new(BADGE_INDEX, BADGE_ATTRIBUTES, "badge.json", "Badges.xml"),
      IndexSettings.new(TAG_INDEX, TAG_ATTRIBUTES, "tag.json", "Tags.xml"),
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

  def process_attr_value(attr_value)
    if ["True", "False"].include?(attr_value)
      return camel_to_snake(attr_value)
    end
    attr_value
  end

  def process_xml_files
    @index_settings.each do |index_setting|
      ElasticBulkHelper.index = index_setting.index_name
      data_file_path = File.join(File.dirname(__FILE__), "/elastic_documents/#{index_setting.data_file}")
      document_bulk = []
      document_bulk_size = 0

      File.foreach(data_file_path) do |line|
        xml_object = Nokogiri::XML(line)
        row_element = xml_object.at_xpath("//row")
        unless row_element.nil?
          document_hash = index_setting.index_attributes.each_with_object({}) do |attr_name, document|
            unless row_element.attr(attr_name).nil?
              document[camel_to_snake(attr_name)] = process_attr_value(row_element.attr(attr_name))
            end
          end
          document_as_json = document_hash.to_json
          if document_bulk_size + document_as_json.bytesize <= MAX_BULK_SIZE
            document_bulk << document_hash
            document_bulk_size += document_as_json.bytesize
          else
            ElasticBulkHelper.ingest(document_bulk)
            document_bulk = [document_hash]
            document_bulk_size = document_as_json.bytesize
          end
        end
      end
      ElasticBulkHelper.ingest(document_bulk)
    end
  end

  def process_posts_xml
    ElasticBulkHelper.index = QUESTION_INDEX
    post_file_path = File.join(File.dirname(__FILE__), "/elastic_documents/Posts.xml")
    question_bulk = []
    question_bulk_size = 0

    File.foreach(post_file_path) do |line|
      xml_object = Nokogiri::XML(line)
      row_element = xml_object.at_xpath("//row")
      unless row_element.nil?
        post = POST_ATTRIBUTES.each_with_object({}) do |attr_name, document|
          unless row_element.attr(attr_name).nil?
            document[camel_to_snake(attr_name)] = process_attr_value(row_element.attr(attr_name))
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
      ElasticBulkHelper.ingest(question_bulk)
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
