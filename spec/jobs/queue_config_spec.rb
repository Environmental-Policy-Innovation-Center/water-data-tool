require "rails_helper"
require "erb"
require "yaml"

RSpec.describe "Solid Queue config" do
  def with_modified_env(values)
    previous = values.keys.to_h { |key| [key, ENV[key]] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  def queue_config(queue_role:)
    with_modified_env("SOLID_QUEUE_ROLE" => queue_role) do
      YAML.safe_load(
        ERB.new(Rails.root.join("config/queue.yml").read).result,
        aliases: true
      ).fetch("default")
    end
  end

  it "uses only non-heavy queues for web workers" do
    workers = queue_config(queue_role: "web").fetch("workers")

    expect(workers).to include(hash_including("queues" => "default", "threads" => 1))
    expect(workers.map { |worker| worker.fetch("queues") }).not_to include("etl", "tile_refresh", "tile_warm")
  end

  it "uses only single-threaded heavy queues for worker services" do
    workers = queue_config(queue_role: "worker").fetch("workers")

    expect(workers).to contain_exactly(
      hash_including("queues" => "etl", "threads" => 1, "processes" => 1),
      hash_including("queues" => "tile_refresh", "threads" => 1, "processes" => 1),
      hash_including("queues" => "tile_warm", "threads" => 1, "processes" => 1)
    )
  end

  it "defaults to the web queue role" do
    workers = queue_config(queue_role: nil).fetch("workers")

    expect(workers.map { |worker| worker.fetch("queues") }).to eq(["default"])
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

  it "allows deployments to override the recurring ETL schedule" do
    with_modified_env(
      "ETL_SCHEDULE_ENABLED" => "true",
      "ETL_SCHEDULE" => "every day at 3am America/New_York"
    ) do
      production_config = YAML.safe_load(
        ERB.new(Rails.root.join("config/recurring.yml").read).result,
        aliases: true
      ).fetch("production")

      expect(production_config.fetch("etl_import").fetch("schedule")).to eq("every day at 3am America/New_York")
    end
  end

  it "omits the recurring ETL job when ETL_SCHEDULE_ENABLED is not true" do
    production_config = recurring_config(schedule_enabled: nil).fetch("production")

    expect(production_config).not_to have_key("etl_import")
  end
end
