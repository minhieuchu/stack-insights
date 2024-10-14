require "singleton"

IndexSettings = Struct.new(:index_name, :mapping_file, :document_attributes, :document_file)

class ElasticManager
  include Singleton
  include Utils

  def initialize
    @index_settings = [
      IndexSettings.new(QUESTION_INDEX, "question.json", POST_ATTRIBUTES, "Posts.xml"),
      IndexSettings.new(COMMENT_INDEX, "comment.json", COMMENT_ATTRIBUTES, "Comments.xml"),
      IndexSettings.new(USER_INDEX, "user.json", USER_ATTRIBUTES, "Users.xml"),
      IndexSettings.new(TAG_INDEX, "tag.json", TAG_ATTRIBUTES, "Tags.xml"),
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

  def index_documents
    @index_settings.each do |index_setting|
      if index_setting.index_name == QUESTION_INDEX
        index_questions
      else
        document_file_path = File.join(File.dirname(__FILE__), "/elastic_documents/#{index_setting.document_file}")
        document_bulk = []
        document_bulk_size = 0

        File.foreach(document_file_path) do |line|
          xml_object = Nokogiri::XML(line)
          row_element = xml_object.at_xpath("//row")
          unless row_element.nil?
            document_hash = index_setting.document_attributes.each_with_object({}) do |attr_name, document|
              unless row_element.attr(attr_name).nil?
                document[camel_to_snake(attr_name)] = refined_attr_value(row_element.attr(attr_name))
              end
            end
            document_bulk << document_hash
            document_bulk_size += document_hash.to_json.bytesize

            if document_bulk_size >= MAX_BULK_SIZE
              bulk_index(index_setting.index_name, document_bulk)
              document_bulk = []
              document_bulk_size = 0
            end
          end
        end
        if document_bulk.length > 0
          resp = bulk_index(index_setting.index_name, document_bulk)
        end
      end
    end
  end

  def index_questions
    post_file_path = File.join(File.dirname(__FILE__), "/elastic_documents/Posts.xml")
    question_bulk = []
    question_bulk_size = 0
    answer_bulk_update_body = []
    answer_bulk_update_body_size = 0

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
          related_question = question_bulk.find { |document| document["id"] == post["parent_id"] }
          unless related_question.nil?
            related_question["answers"] << post
            question_bulk_size += post.to_json.bytesize
          else
            update_params = [
              { update: { _id: post["parent_id"], _index: QUESTION_INDEX } },
              {
                script: {
                  source: "ctx._source.answers.add(params.answer)",
                  params: {
                    answer: post,
                  },
                },
              },
            ]
            answer_bulk_update_body.push(*update_params)
            answer_bulk_update_body_size += update_params.to_json.bytesize
          end
        end

        if question_bulk_size >= MAX_BULK_SIZE
          bulk_index(QUESTION_INDEX, question_bulk)
          question_bulk = []
          question_bulk_size = 0
        end

        if answer_bulk_update_body_size >= MAX_BULK_SIZE
          ElasticClient.bulk(
            body: answer_bulk_update_body,
            refresh: "true",
          )
          answer_bulk_update_body = []
          answer_bulk_update_body_size = 0
        end
      end
    end

    if question_bulk.length > 0
      bulk_index(QUESTION_INDEX, question_bulk)
    end

    if answer_bulk_update_body.length > 0
      ElasticClient.bulk(
        body: answer_bulk_update_body,
        refresh: "true",
      )
    end
  end

  def search_questions(keywords)
    question_response = ElasticClient.search(
      index: QUESTION_INDEX,
      size: RECORD_SIZE,
      body: {
        _source: {
          exclude: ["answers"],
        },
        query: {
          bool: {
            should: [
              { match: { title: keywords } },
              { match: { body: keywords } },
              { match: { tags: keywords } },
              {
                nested: {
                  path: "answers",
                  query: {
                    match: {
                      "answers.body": keywords,
                    },
                  },
                },
              },
            ],
            minimum_should_match: 1,
          },
        },
      },
    )
    questions = question_response.dig("hits", "hits").map { |document| document.dig("_source") }
    related_user_ids = questions.map { |question| question["owner_user_id"] }.reject { |user_id| user_id.nil? }
    users_response = ElasticClient.search(
      index: USER_INDEX,
      size: RECORD_SIZE,
      body: {
        query: {
          ids: {
            values: related_user_ids,
          },
        },
      },
    )
    users = users_response.dig("hits", "hits").map { |document| document.dig("_source") }

    questions.each do |question|
      question["owner_user"] = users.find { |user| user["id"] == question["owner_user_id"] }
    end
  end

  private

  def refined_attr_value(attr_value)
    if ["True", "False"].include?(attr_value)
      return camel_to_snake(attr_value)
    end
    attr_value
  end

  def bulk_index(index_name, document_bulk)
    bulk_request_body = document_bulk.map do |document|
      [
        { index: { _index: index_name, _id: document["id"] } },
        document,
      ]
    end.flatten

    ElasticClient.bulk(
      body: bulk_request_body,
      refresh: "true",
    )
  end
end
