class ElasticQuery
  def self.query(keywords)
    ElasticClient.search(index: POST_INDEX, body: { query: { match: { title: keywords } } })
  end
end
