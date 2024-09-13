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

ElasticClient = Elasticsearch::Client.new(
  url: "http://localhost:9200/",
  log: Rails.env.development?,
)

Rails.application.config.after_initialize do
  ElasticManager.create_elastic_indexes
end
