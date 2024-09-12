class FileIngestService
  extend Utils

  def self.create_elasticsearch_indexes
    posts_settings = JSON.parse(File.read(File.join(File.dirname(__FILE__), "/es_indexes/post.json")))

    unless ESClient.indices.exists?(index: POST_INDEX_NAME)
      ESClient.indices.create(index: POST_INDEX_NAME, body: posts_settings)
    end
  end

  def self.process_xml_files
    posts_file_path = File.join(File.dirname(__FILE__), "/Posts.xml")
    File.foreach(posts_file_path) do |line|
      xml_object = Nokogiri::XML(line)
      row_element = xml_object.at_xpath("//row")
      unless row_element.nil?
        post_object = POST_ATTRIBUTES.each_with_object({}) do |attr_name, post|
          post[camel_to_snake(attr_name)] = row_element.attr(attr_name)
        end
        ESClient.index(index: POST_INDEX_NAME, body: post_object.to_json)
      end
    end
  end
end
