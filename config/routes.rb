Rails.application.routes.draw do
  root "home#index"
  get "/table", to: "home#table", as: :table

  get "/tiles/:z/:x/:y", to: "tiles#show", as: :tile, constraints: {z: /\d+/, x: /\d+/, y: /\d+/}

  get "up" => "rails/health#show", :as => :rails_health_check

  get "/places/search", to: "places#search"

  resources :public_water_systems, param: :pwsid, only: %i[index show],
    constraints: {pwsid: /[A-Z]{2}\d{7}/} do
    collection do
      resource :stats, only: :show, module: :public_water_systems
      resource :export, only: :show, module: :public_water_systems
    end
    member do
      resource :report, only: :show, module: :public_water_systems
    end
  end
end
