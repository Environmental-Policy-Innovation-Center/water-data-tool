require "rails_helper"

RSpec.describe TileBenchmark do
  describe ".budget_for" do
    it "uses the overview tier for z0-z4" do
      [0, 4].each do |z|
        budget = described_class.budget_for(z, env: {})

        expect(budget.tier).to eq("overview")
        expect(budget.warn_ms).to eq(3000)
        expect(budget.fail_ms).to eq(8000)
        expect(budget.db_timeout_ms).to eq(10_000)
      end
    end

    it "uses the state-selection tier for z5-z7" do
      [5, 7].each do |z|
        budget = described_class.budget_for(z, env: {})

        expect(budget.tier).to eq("state selection")
        expect(budget.warn_ms).to eq(2000)
        expect(budget.fail_ms).to eq(6000)
        expect(budget.db_timeout_ms).to eq(8000)
      end
    end

    it "uses the system-browsing tier for z8 and above" do
      [8, 12].each do |z|
        budget = described_class.budget_for(z, env: {})

        expect(budget.tier).to eq("system browsing")
        expect(budget.warn_ms).to eq(1000)
        expect(budget.fail_ms).to eq(4000)
        expect(budget.db_timeout_ms).to eq(6000)
      end
    end
  end

  describe ".expected_layers" do
    it "delegates expected layer counts to TileGenerator.layers_for_zoom" do
      allow(TileGenerator).to receive(:layers_for_zoom).with(7).and_return(%w[pws counties states])

      expect(described_class.expected_layers(7)).to eq(%w[pws counties states])
    end
  end

  describe TileBenchmark::Runner do
    let(:sample) { TileBenchmark::Sample.new(z: 5, x: 9, y: 12) }
    let(:output) { StringIO.new }
    let(:tile_generator) do
      Class.new do
        def self.layers_for_zoom(_z)
          %w[pws counties states]
        end

        def self.layer_simplification_tolerance(_layer, _z)
          0.01
        end

        def self.generate_layer(_layer, _z, _x, _y, _simp)
          "mvt".b
        end

        def self.build_tile(_z, _x, _y)
          "mvt".b
        end
      end
    end

    it "exits nonzero when a completed sample exceeds the fail budget" do
      runner = described_class.new(
        samples: [sample],
        output: output,
        tile_generator: tile_generator,
        cache_model: class_double(TileCache, where: double(count: 0)),
        clock: fake_clock(0.0, 7.5),
        env: {"TILE_BENCH_FAIL_MS_Z5_7" => "6000"}
      )

      report = runner.run

      expect(report.exit_status).to eq(1)
      expect(report.results.first.status).to eq(:fail)
      expect(report.results.first.timeout?).to be(false)
    end

    it "marks timeout failures distinctly from slow completed samples" do
      timeout_generator = Class.new(tile_generator) do
        def self.generate_layer(_layer, _z, _x, _y, _simp)
          raise Timeout::Error
        end
      end

      runner = described_class.new(
        samples: [sample],
        output: output,
        tile_generator: timeout_generator,
        cache_model: class_double(TileCache, where: double(count: 0)),
        clock: fake_clock(0.0, 6.0),
        env: {}
      )

      report = runner.run

      expect(report.exit_status).to eq(1)
      expect(report.results.first.status).to eq(:timeout)
      expect(report.results.first.timeout?).to be(true)
    end

    it "marks samples that run through the database timeout as timeout failures" do
      runner = described_class.new(
        samples: [sample],
        output: output,
        tile_generator: tile_generator,
        cache_model: class_double(TileCache, where: double(count: 0)),
        clock: fake_clock(0.0, 8.0),
        env: {"TILE_BENCH_DB_TIMEOUT_MS_Z5_7" => "8000"}
      )

      report = runner.run

      expect(report.exit_status).to eq(1)
      expect(report.results.first.status).to eq(:timeout)
      expect(report.results.first.timeout?).to be(true)
    end

    it "uses TileGenerator.layers_for_zoom for expected warm cache layer counts" do
      relation = double(count: 3)
      expect(tile_generator).to receive(:layers_for_zoom).with(5).and_call_original
      expect(tile_generator).to receive(:build_tile).with(5, 9, 12).and_return("warm".b)

      runner = described_class.new(
        samples: [sample],
        output: output,
        tile_generator: tile_generator,
        cache_model: class_double(TileCache, where: relation),
        clock: fake_clock(0.0, 0.1, 0.1, 0.2),
        env: {}
      )

      report = runner.run

      expect(report.results.map(&:mode)).to include(:warm)
    end

    def fake_clock(*values)
      Class.new do
        define_singleton_method(:values) { @values ||= values.dup }
        define_singleton_method(:monotonic) { self.values.shift }
      end
    end
  end
end
