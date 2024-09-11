class ApiFileIngestService
  def read_xml_file
    file_path = File.join(File.dirname(__FILE__), "/Posts.xml")
    File.foreach(file_path) do |line|
      xml_object = Nokogiri::XML(line)
      row_element = xml_object.at_xpath("//row")
      unless row_element.nil?
        puts row_element.attr("Body")
      end
    end
  end
end
