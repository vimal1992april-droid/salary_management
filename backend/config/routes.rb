Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    get "health", to: "health#show"
    get "lookups", to: "lookups#show"

    scope "insights", controller: "insights", as: "insights" do
      get "overview"
      get "salary_stats"
      get "distribution"
      get "top_earners"
      get "outliers"
    end

    resource :session, only: %i[show create destroy]
    get "employees/export", to: "employee_exports#show", as: :employee_export
    resources :employees, only: %i[index show create update] do
      resources :salary_changes, only: %i[index create]
    end
  end
end
