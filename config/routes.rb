Rails.application.routes.draw do
  root "pages#landing"

  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  get  "dashboard", to: "dashboard#index", as: :dashboard
  resources :installations, only: [:index, :new, :create, :show, :destroy]
  resources :pull_requests, only: [:show]
  resources :reviews, only: [:show]
  resource  :settings, only: [:show, :update]

  post "webhooks/github", to: "webhooks#github"

  get "up" => "rails/health#show", as: :rails_health_check
end
