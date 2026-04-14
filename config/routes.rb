Rails.application.routes.draw do
  root "home#index"

  get "/tiles/:z/:x/:y", to: "tiles#show", as: :tile, constraints: {z: /\d+/, x: /\d+/, y: /\d+/}

  get "up" => "rails/health#show", :as => :rails_health_check
end
