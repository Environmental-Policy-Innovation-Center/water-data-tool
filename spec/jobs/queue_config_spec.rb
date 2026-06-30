require "rails_helper"
require "erb"
require "yaml"

RSpec.describe "Solid Queue config" do
  subject(:config) do
    YAML.safe_load(
      ERB.new(Rails.root.join("config/queue.yml").read).result,
      aliases: true
    ).fetch("default")
  end

  it "runs ETL and tile refresh queues with one thread each" do
    workers = config.fetch("workers")

    expect(workers).to include(hash_including("queues" => "etl", "threads" => 1, "processes" => 1))
    expect(workers).to include(hash_including("queues" => "tile_refresh", "threads" => 1, "processes" => 1))
  end

  it "does not use broad default queue concurrency for heavy map work" do
    default_worker = config.fetch("workers").find { |worker| worker.fetch("queues") == "default" }

    expect(default_worker.fetch("threads")).to eq(1)
  end
end

RSpec.describe "Solid Queue recurring config" do
  def with_modified_env(values)
    previous = values.keys.to_h { |key| [key, ENV[key]] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  def recurring_config(schedule_enabled:)
    with_modified_env("ETL_SCHEDULE_ENABLED" => schedule_enabled) do
      YAML.safe_load(
        ERB.new(Rails.root.join("config/recurring.yml").read).result,
        aliases: true
      )
    end
  end

  it "includes the recurring ETL job when ETL_SCHEDULE_ENABLED is true" do
    production_config = recurring_config(schedule_enabled: "true").fetch("production")

    expect(production_config).to include("etl_import" => hash_including("class" => "EtlImportJob"))
  end

  it "omits the recurring ETL job when ETL_SCHEDULE_ENABLED is not true" do
    production_config = recurring_config(schedule_enabled: nil).fetch("production")

    expect(production_config).not_to have_key("etl_import")
  end
end
