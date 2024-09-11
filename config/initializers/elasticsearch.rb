require "elasticsearch"

ESClient = Elasticsearch::Client.new(
  url: "http://localhost:9200/",
  log: Rails.env.development?,
)
