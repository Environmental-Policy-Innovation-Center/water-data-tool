class AppConfig
  S3_BASE_URL = "https://tech-team-data.s3.us-east-1.amazonaws.com/national-dw-tool"
  METHODOLOGY_PDF_PATH = "public-data-downloads/EPIC's+Drinking+Water+Explorer+Tool+-+Methodology.pdf"

  class << self
    def app_env
      ENV["APP_ENV"].presence || Rails.env.to_s
    end

    def public_downloads_base_url
      env_url("PUBLIC_DOWNLOADS_BASE_URL") || "#{S3_BASE_URL}/public-data-downloads/#{s3_environment_folder}"
    end

    def methodology_pdf_url
      env_url("METHODOLOGY_PDF_URL") || "#{S3_BASE_URL}/#{METHODOLOGY_PDF_PATH}"
    end

    def etl_schedule_enabled?
      ENV["ETL_SCHEDULE_ENABLED"] == "true"
    end

    private

    def env_url(name)
      ENV[name].presence&.chomp("/")
    end

    def s3_environment_folder
      case app_env
      when "production"
        "prod"
      when "staging"
        "staging"
      else
        "staging"
      end
    end
  end
end
