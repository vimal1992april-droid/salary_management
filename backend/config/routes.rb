Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    get "health", to: "health#show"
    get "lookups", to: "lookups#show"

    resource :session, only: %i[show create destroy]
    resources :employees, only: %i[index show create update]
  end
end
