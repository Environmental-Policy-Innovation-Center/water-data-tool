Rails.application.routes.draw do
  if Rails.env.development?
    mount Lookbook::Engine, at: "/lookbook"
  end

  root "home#index"
  get "/table", to: "home#table", as: :table
  get "/map", to: "home#map", as: :map

  get "/tiles/:z/:x/:y", to: "tiles#show", as: :tile, constraints: {z: /\d+/, x: /\d+/, y: /\d+/}

  get "up" => "rails/health#show", :as => :rails_health_check

  get "/places/search", to: "places#search"

  resources :public_water_systems, param: :pwsid, only: [],
    constraints: {pwsid: /[A-Z0-9;%]+/} do
    collection do
      resource :export, only: :create, module: :public_water_systems
      resource :histogram, only: :show, module: :public_water_systems
      resource :stats, only: :show, module: :public_water_systems
    end
    member do
      resource :report, only: :show, module: :public_water_systems
    end
  end
end
