class ElasticController < ApplicationController
  def search_questions
    response = ElasticManager.instance.search_questions(params[:q])
    render json: response, status: :ok
  end
end
