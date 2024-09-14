require "singleton"

IndexSettings = Struct.new(:index_name, :index_attributes, :mapping_file, :data_file)

class ElasticManager
  include Singleton
  include Utils

  def initialize
    @index_settings = [
      IndexSettings.new(POST_INDEX, POST_ATTRIBUTES, "post.json", "Posts.xml"),
      IndexSettings.new(USER_INDEX, USER_ATTRIBUTES, "user.json", "Users.xml"),
    ]
  end

  def create_indexes
    @index_settings.each do |index_setting|
      index_mappings = JSON.parse(File.read(File.join(File.dirname(__FILE__), "/elastic_indexes/#{index_setting.mapping_file}")))

      unless ElasticClient.indices.exists?(index: index_setting.index_name)
        ElasticClient.indices.create(index: index_setting.index_name, body: index_mappings)
      end
    end
  end

  def process_xml_files
    @index_settings.each do |index_setting|
      ElasticBulkHelper.index = index_setting.index_name
      data_file_path = File.join(File.dirname(__FILE__), "/#{index_setting.data_file}")
      document_bulk = []
      document_bulk_size = 0

      File.foreach(data_file_path) do |line|
        xml_object = Nokogiri::XML(line)
        row_element = xml_object.at_xpath("//row")
        unless row_element.nil?
          document_hash = index_setting.index_attributes.each_with_object({}) do |attr_name, document|
            document[camel_to_snake(attr_name)] = row_element.attr(attr_name)
          end
          document_as_json = document_hash.to_json
          if document_bulk_size + document_as_json.bytesize <= BULK_SIZE
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

  def reset_indexes
    @index_settings.each do |index_setting|
      ElasticClient.indices.delete(index: index_setting.index_name)
    end
    create_indexes
  end
end
