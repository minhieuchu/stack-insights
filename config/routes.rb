Rails.application.routes.draw do
  get "/search", to: "elastic#search_questions"
end
