namespace :elasticsearch do
  desc "Parse XML file to generate input to Elasticsearch"
  task file_ingest: :environment do
    ElasticManager.instance.process_xml_files
  end
end
