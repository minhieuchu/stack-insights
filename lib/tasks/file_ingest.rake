desc "Parse XML file to generate input to Elasticsearch"
task file_ingest: :environment do
  FileIngestService.process_xml_files
end
