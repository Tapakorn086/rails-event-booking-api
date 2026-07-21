Rails.application.routes.draw do
  resources :events, only: [:index] do
    resources :bookings, only: [:create]
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
