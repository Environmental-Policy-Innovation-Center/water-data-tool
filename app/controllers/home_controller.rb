class HomeController < ApplicationController
  def index
    @last_updated = DataImport.maximum(:imported_at)
  end
end
