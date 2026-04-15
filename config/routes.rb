Rails.application.routes.draw do
  root "home#index"
  get "/table", to: "home#table", as: :table

  get "/tiles/:z/:x/:y", to: "tiles#show", as: :tile, constraints: {z: /\d+/, x: /\d+/, y: /\d+/}

  get "up" => "rails/health#show", :as => :rails_health_check

  resources :reports, param: :pwsid, only: [:show]

  resources :public_water_systems, param: :pwsid, only: %i[index show] do
    collection do
      get :export
    end
  end
end
