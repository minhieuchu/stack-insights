class EsQueryService
  def self.query(keywords)
    ESClient.search(index: POST_INDEX_NAME, body: { query: { match: { title: keywords } } })
  end
end
