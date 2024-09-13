class ElasticManager
  extend Utils

  def self.create_elastic_indexes
    posts_settings = JSON.parse(File.read(File.join(File.dirname(__FILE__), "/elastic_indexes/post.json")))

    unless ElasticClient.indices.exists?(index: POST_INDEX)
      ElasticClient.indices.create(index: POST_INDEX, body: posts_settings)
    end
  end

  def self.process_xml_files
    # Process posts
    ElasticBulkHelper.index = POST_INDEX
    posts_file_path = File.join(File.dirname(__FILE__), "/Posts.xml")
    post_bulk = []
    post_bulk_size = 0
    File.foreach(posts_file_path) do |line|
      xml_object = Nokogiri::XML(line)
      row_element = xml_object.at_xpath("//row")
      unless row_element.nil?
        post_object = POST_ATTRIBUTES.each_with_object({}) do |attr_name, post|
          post[camel_to_snake(attr_name)] = row_element.attr(attr_name)
        end
        post_as_json = post_object.to_json
        if post_bulk_size + post_as_json.bytesize <= BULK_SIZE
          post_bulk << post_object
          post_bulk_size += post_as_json.bytesize
        else
          ElasticBulkHelper.ingest(post_bulk)
          post_bulk = [post_object]
          post_bulk_size = post_as_json.bytesize
        end
      end
    end
    ElasticBulkHelper.ingest(post_bulk)
  end

  def self.reset_elastic_indexes
    ElasticClient.indices.delete(index: POST_INDEX)
    create_elastic_indexes
  end
end
