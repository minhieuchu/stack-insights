desc "Parse XML file to generate input to Elasticsearch"
task api_file_ingest: :environment do
  ApiFileIngestService.new.read_xml_file
end
