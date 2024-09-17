class ElasticController < ApplicationController
  def index
    response = ElasticManager.instance.query(params[:q])
    render json: response, status: :ok
  end
end
