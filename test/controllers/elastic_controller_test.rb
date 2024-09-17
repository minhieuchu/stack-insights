require "test_helper"

class ElasticControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get elastic_index_url
    assert_response :success
  end
end
