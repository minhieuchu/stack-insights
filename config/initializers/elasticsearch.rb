require "elasticsearch"
require "elasticsearch/helpers/bulk_helper"

QUESTION_INDEX = "questions"
USER_INDEX = "users"
COMMENT_INDEX = "comments"
BADGE_INDEX = "badges"
TAG_INDEX = "tags"

POST_ATTRIBUTES = [
  "Id",
  "Title",
  "Tags",
  "Body",
  "Score",
  "ParentId",
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
COMMENT_ATTRIBUTES = [
  "Id",
  "PostId",
  "Score",
  "Text",
  "CreationDate",
  "UserDisplayName",
  "UserId",
  "ContentLicense",
]
BADGE_ATTRIBUTES = [
  "Id",
  "UserId",
  "Name",
  "Date",
  "Class",
  "TagBased",
]
TAG_ATTRIBUTES = [
  "Id",
  "TagName",
  "Count",
  "ExcerptPostId",
  "WikiPostId",
  "IsModeratorOnly",
  "IsRequired",
]
MAX_BULK_SIZE = 500  # 9 * 10 ** 6  # 9MB

ElasticClient = Elasticsearch::Client.new(
  url: "http://localhost:9200/", # Todo: Set env variable
  log: Rails.env.development?,
)

Rails.application.config.after_initialize do
  ElasticManager.instance.create_indices
  ElasticBulkHelper = Elasticsearch::Helpers::BulkHelper.new(ElasticClient, QUESTION_INDEX)
end
