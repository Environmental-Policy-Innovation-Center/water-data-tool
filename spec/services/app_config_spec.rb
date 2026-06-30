require "rails_helper"

RSpec.describe AppConfig do
  def with_modified_env(values)
    previous = values.keys.to_h { |key| [key, ENV[key]] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  describe ".app_env" do
    it "uses APP_ENV when present" do
      with_modified_env("APP_ENV" => "staging") do
        expect(described_class.app_env).to eq("staging")
      end
    end

    it "falls back to the Rails environment" do
      with_modified_env("APP_ENV" => nil) do
        expect(described_class.app_env).to eq(Rails.env.to_s)
      end
    end
  end

  describe ".public_downloads_base_url" do
    it "uses PUBLIC_DOWNLOADS_BASE_URL when present and removes a trailing slash" do
      with_modified_env("PUBLIC_DOWNLOADS_BASE_URL" => "https://cdn.example.test/downloads/staging/") do
        expect(described_class.public_downloads_base_url).to eq("https://cdn.example.test/downloads/staging")
      end
    end

    it "generates the staging S3 downloads folder for APP_ENV=staging" do
      with_modified_env("APP_ENV" => "staging", "PUBLIC_DOWNLOADS_BASE_URL" => nil) do
        expect(described_class.public_downloads_base_url)
          .to eq("https://tech-team-data.s3.us-east-1.amazonaws.com/national-dw-tool/public-data-downloads/staging")
      end
    end

    it "generates the production S3 downloads folder for APP_ENV=production" do
      with_modified_env("APP_ENV" => "production", "PUBLIC_DOWNLOADS_BASE_URL" => nil) do
        expect(described_class.public_downloads_base_url)
          .to eq("https://tech-team-data.s3.us-east-1.amazonaws.com/national-dw-tool/public-data-downloads/prod")
      end
    end
  end

  describe ".methodology_pdf_url" do
    it "uses METHODOLOGY_PDF_URL when present" do
      with_modified_env("METHODOLOGY_PDF_URL" => "https://cdn.example.test/methodology.pdf") do
        expect(described_class.methodology_pdf_url).to eq("https://cdn.example.test/methodology.pdf")
      end
    end
  end

  describe ".etl_schedule_enabled?" do
    it "is true only when ETL_SCHEDULE_ENABLED is true" do
      with_modified_env("ETL_SCHEDULE_ENABLED" => "true") do
        expect(described_class.etl_schedule_enabled?).to be(true)
      end

      with_modified_env("ETL_SCHEDULE_ENABLED" => nil) do
        expect(described_class.etl_schedule_enabled?).to be(false)
      end
    end
  end
end
