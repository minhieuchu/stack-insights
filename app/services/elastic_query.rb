require "singleton"

class ElasticQuery
  include Singleton

  def query(keywords)
    response = ElasticClient.search(index: POST_INDEX, body: { query: { match: { title: keywords } } })
    results = response["hits"]["hits"].map { |hit| hit["_source"] }
  end
end
