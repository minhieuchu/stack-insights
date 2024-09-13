require "elasticsearch"
require "elasticsearch/helpers/bulk_helper"

POST_INDEX = "posts"
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
BULK_SIZE = 9 * 10 ** 6  # 9MB

ElasticClient = Elasticsearch::Client.new(
  url: "http://localhost:9200/", # Todo: Set env variable
  log: Rails.env.development?,
)

ElasticBulkHelper = Elasticsearch::Helpers::BulkHelper.new(ElasticClient, POST_INDEX)

Rails.application.config.after_initialize do
  ElasticManager.create_elastic_indexes
end
