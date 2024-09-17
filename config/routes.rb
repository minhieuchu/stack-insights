Rails.application.routes.draw do
  get "/search", to: "elastic#index"
end
