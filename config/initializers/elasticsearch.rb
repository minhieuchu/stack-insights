require "elasticsearch"
require "elasticsearch/helpers/bulk_helper"

POST_INDEX = "posts"
USER_INDEX = "users"

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
USER_ATTRIBUTES = [
  "Id",
  "Reputation",
  "CreationDate",
  "DisplayName",
  "WebsiteUrl",
  "Location",
  "AboutMe",
  "Views",
  "UpVotes",
  "DownVotes",
  "ProfileImageUrl",
  "AccountId",
]
BULK_SIZE = 9 * 10 ** 6  # 9MB

ElasticClient = Elasticsearch::Client.new(
  url: "http://localhost:9200/", # Todo: Set env variable
  log: Rails.env.development?,
)

Rails.application.config.after_initialize do
  ElasticManager.instance.create_indexes
  ElasticBulkHelper = Elasticsearch::Helpers::BulkHelper.new(ElasticClient, POST_INDEX)
end
