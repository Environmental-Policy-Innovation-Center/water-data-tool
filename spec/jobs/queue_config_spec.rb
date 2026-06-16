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
