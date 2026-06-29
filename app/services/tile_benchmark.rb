require "timeout"

module TileBenchmark
  Budget = Data.define(:tier, :warn_ms, :fail_ms, :db_timeout_ms)
  Sample = Data.define(:z, :x, :y)
  Result = Data.define(:mode, :layer, :sample, :tier, :elapsed_ms, :size_bytes, :status, :message) do
    def timeout?
      status == :timeout
    end
  end
  Report = Data.define(:results) do
    def exit_status
      failing_results? ? 1 : 0
    end

    def failing_results?
      results.any? { |result| %i[fail timeout].include?(result.status) }
    end
  end

  DEFAULT_SAMPLES = [
    Sample.new(z: 2, x: 0, y: 1),
    Sample.new(z: 5, x: 9, y: 12),
    Sample.new(z: 8, x: 59, y: 95)
  ].freeze

  module_function

  def budget_for(z, env: ENV)
    case z
    when 0..4
      Budget.new(
        tier: "overview",
        warn_ms: env.fetch("TILE_BENCH_WARN_MS_Z0_4", "3000").to_i,
        fail_ms: env.fetch("TILE_BENCH_FAIL_MS_Z0_4", "8000").to_i,
        db_timeout_ms: env.fetch("TILE_BENCH_DB_TIMEOUT_MS_Z0_4", env.fetch("TILE_BENCH_DB_TIMEOUT_MS", "10000")).to_i
      )
    when 5..7
      Budget.new(
        tier: "state selection",
        warn_ms: env.fetch("TILE_BENCH_WARN_MS_Z5_7", "2000").to_i,
        fail_ms: env.fetch("TILE_BENCH_FAIL_MS_Z5_7", "6000").to_i,
        db_timeout_ms: env.fetch("TILE_BENCH_DB_TIMEOUT_MS_Z5_7", env.fetch("TILE_BENCH_DB_TIMEOUT_MS", "8000")).to_i
      )
    else
      Budget.new(
        tier: "system browsing",
        warn_ms: env.fetch("TILE_BENCH_WARN_MS_Z8_PLUS", "1000").to_i,
        fail_ms: env.fetch("TILE_BENCH_FAIL_MS_Z8_PLUS", "4000").to_i,
        db_timeout_ms: env.fetch("TILE_BENCH_DB_TIMEOUT_MS_Z8_PLUS", env.fetch("TILE_BENCH_DB_TIMEOUT_MS", "6000")).to_i
      )
    end
  end

  def warm_budget(env: ENV)
    Budget.new(
      tier: "warm cache",
      warn_ms: env.fetch("TILE_BENCH_WARN_MS_WARM", "200").to_i,
      fail_ms: env.fetch("TILE_BENCH_FAIL_MS_WARM", "1000").to_i,
      db_timeout_ms: 0
    )
  end

  def expected_layers(z, tile_generator: TileGenerator)
    tile_generator.layers_for_zoom(z)
  end

  class Runner
    def initialize(samples: DEFAULT_SAMPLES, output: $stdout, tile_generator: TileGenerator, cache_model: TileCache, clock: nil, env: ENV, connection: nil)
      @samples = samples
      @output = output
      @tile_generator = tile_generator
      @cache_model = cache_model
      @clock = clock || MonotonicClock
      @env = env
      @connection = connection
    end

    def run
      puts_line "Tile Benchmark Guard"
      puts_line "Cold timings use TileGenerator.generate_layer and do not write tile_cache."
      puts_line ""

      results = []
      @samples.each do |sample|
        expected_layers = TileBenchmark.expected_layers(sample.z, tile_generator: @tile_generator)
        budget = TileBenchmark.budget_for(sample.z, env: @env)
        puts_line format("z=%<z>d x=%<x>d y=%<y>d  tier=%<tier>s  expected_layers=%<count>d (%<layers>s)",
          z: sample.z,
          x: sample.x,
          y: sample.y,
          tier: budget.tier,
          count: expected_layers.count,
          layers: expected_layers.join(","))

        cold_layers(sample.z, expected_layers).each do |layer|
          result = measure_cold_layer(sample, layer, budget)
          results << result
          print_result(result)
        end

        warm_result = measure_warm_tile(sample, expected_layers)
        if warm_result
          results << warm_result
          print_result(warm_result)
        else
          puts_line "  warm build_tile skipped: cached layers missing"
        end

        puts_line ""
      end

      report = Report.new(results: results)
      puts_line(report.exit_status.zero? ? "PASS: all measured tile samples are within fail budgets" : "FAIL: one or more tile samples exceeded fail budgets")
      report
    end

    private

    def cold_layers(z, expected_layers)
      return expected_layers if z >= 8

      expected_layers.include?("pws") ? ["pws"] : expected_layers
    end

    def measure_cold_layer(sample, layer, budget)
      elapsed_ms = nil
      tile = "".b

      begin
        elapsed_ms = measure_ms do
          with_db_statement_timeout(budget.db_timeout_ms) do
            Timeout.timeout(budget.db_timeout_ms / 1000.0) do
              tile = @tile_generator.generate_layer(
                layer,
                sample.z,
                sample.x,
                sample.y,
                @tile_generator.layer_simplification_tolerance(layer, sample.z)
              )
            end
          end
        end
      rescue Timeout::Error
        elapsed_ms ||= budget.db_timeout_ms
        return Result.new(mode: :cold, layer: layer, sample: sample, tier: budget.tier, elapsed_ms: elapsed_ms.round, size_bytes: 0, status: :timeout, message: "timed out at #{budget.db_timeout_ms}ms")
      end

      Result.new(
        mode: :cold,
        layer: layer,
        sample: sample,
        tier: budget.tier,
        elapsed_ms: elapsed_ms.round,
        size_bytes: tile.to_s.bytesize,
        status: cold_status_for(elapsed_ms, budget),
        message: cold_budget_message(elapsed_ms, budget)
      )
    end

    def measure_warm_tile(sample, expected_layers)
      cached_count = @cache_model.where(z: sample.z, x: sample.x, y: sample.y).count
      return nil unless cached_count >= expected_layers.count

      budget = TileBenchmark.warm_budget(env: @env)
      tile = "".b
      elapsed_ms = measure_ms { tile = @tile_generator.build_tile(sample.z, sample.x, sample.y) }

      Result.new(
        mode: :warm,
        layer: "all",
        sample: sample,
        tier: budget.tier,
        elapsed_ms: elapsed_ms.round,
        size_bytes: tile.to_s.bytesize,
        status: status_for(elapsed_ms, budget),
        message: budget_message(elapsed_ms, budget)
      )
    end

    def with_db_statement_timeout(timeout_ms)
      return yield unless @connection

      @connection.transaction(requires_new: true) do
        @connection.execute("SET LOCAL statement_timeout = #{Integer(timeout_ms)}")
        yield
      end
    end

    def measure_ms
      started = @clock.monotonic
      yield
      (@clock.monotonic - started) * 1000
    end

    def status_for(elapsed_ms, budget)
      return :fail if elapsed_ms > budget.fail_ms
      return :warn if elapsed_ms > budget.warn_ms

      :pass
    end

    def cold_status_for(elapsed_ms, budget)
      return :timeout if elapsed_ms >= budget.db_timeout_ms

      status_for(elapsed_ms, budget)
    end

    def budget_message(elapsed_ms, budget)
      return "over fail budget #{budget.fail_ms}ms" if elapsed_ms > budget.fail_ms
      return "over warn budget #{budget.warn_ms}ms" if elapsed_ms > budget.warn_ms

      "within budget"
    end

    def cold_budget_message(elapsed_ms, budget)
      return "timed out at #{budget.db_timeout_ms}ms" if elapsed_ms >= budget.db_timeout_ms

      budget_message(elapsed_ms, budget)
    end

    def print_result(result)
      puts_line format("  %-5s %-8s %6dms %7.1f KB  %-7s %s",
        result.mode,
        result.layer,
        result.elapsed_ms,
        result.size_bytes / 1024.0,
        result.status.to_s.upcase,
        result.message)
    end

    def puts_line(text)
      @output.puts(text)
    end
  end

  module MonotonicClock
    module_function

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
