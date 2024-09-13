class EsQueryService
  def self.query(keywords)
    ElasticClient.search(index: POST_INDEX_NAME, body: { query: { match: { title: keywords } } })
  end
end
