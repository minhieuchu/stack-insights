require "elasticsearch"

POST_INDEX_NAME = "posts"
POST_ATTRIBUTES = [
  "Id",
  "Title",
  "Tags",
  "Body",
  "Score",
  "ViewCount",
  "PostTypeId",
  "OwnerUserId",
  "AnswerCount",
  "LastEditDate",
  "LastActivityDate",
  "OwnerDisplayName",
]

ESClient = Elasticsearch::Client.new(
  url: "http://localhost:9200/",
  log: Rails.env.development?,
)

Rails.application.config.after_initialize do
  FileIngestService.create_elasticsearch_indexes
end
