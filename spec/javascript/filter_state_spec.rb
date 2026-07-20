require "rails_helper"
require "open3"
require "tempfile"

RSpec.describe "filter_state URL seeding" do
  def run_node_script(script)
    Tempfile.create(["filter-state", ".js"]) do |file|
      file.write(script)
      file.flush

      stdout, stderr, status = Open3.capture3("node", file.path)
      expect(status).to be_success, [stdout, stderr].reject(&:empty?).join("\n")
    end
  end

  # Strips the ES import (stubbed inline per test) and rewrites `export const` to a global
  # assignment so eval()'d sloppy-mode code exposes get/set the same way the browser's
  # module scope would.
  def source_without_imports
    Rails.root.join("app/javascript/filter_state.js").read
      .sub(/^import.*\n/, "")
      .gsub(/^export const (\w+) = /, 'global.\1 = ')
  end

  # Controllers register via independent parallel dynamic imports (eagerLoadControllersFrom), so
  # whichever controller's module resolves first connects first — not necessarily filter_controller,
  # which is the only one that reads the URL. Every controller that touches FilterState reaches it
  # via a static `import`, so the fix seeds FilterState from the URL at module-evaluation time
  # instead of reactively from filter_controller#connect — closing the race for good.
  it "has the URL-restored state available immediately, before any controller calls set()" do
    script = <<~JS
      global.window = { location: { search: "?encoded=eJytest" } }
      const decodeState = (encoded) => {
        if (encoded !== "eJytest") return {}
        return { filters: { state: "TX", state_name: "Texas", groundwater_rule_5yr_min: "1", groundwater_rule_5yr_max: "1" } }
      }

      #{source_without_imports}

      const filters = get()
      if (filters.state !== "TX") throw new Error(`expected state TX, got ${filters.state}`)
      if (filters.groundwater_rule_5yr_min !== "1") throw new Error(`expected min 1, got ${filters.groundwater_rule_5yr_min}`)
      console.log("ok")
    JS
    run_node_script(script)
  end

  it "starts empty when the URL carries no encoded param" do
    script = <<~JS
      global.window = { location: { search: "" } }
      const decodeState = () => { throw new Error("decodeState should not be called without an encoded param") }

      #{source_without_imports}

      const filters = get()
      if (Object.keys(filters).length !== 0) throw new Error(`expected empty state, got ${JSON.stringify(filters)}`)
      console.log("ok")
    JS
    run_node_script(script)
  end

  it "still allows set() to fully replace the seeded state, same as before" do
    script = <<~JS
      global.window = { location: { search: "?encoded=eJytest" } }
      const decodeState = () => ({ filters: { state: "TX" } })

      #{source_without_imports}

      set({ state: "OH", state_name: "Ohio" })
      const filters = get()
      if (filters.state !== "OH") throw new Error(`expected state OH, got ${filters.state}`)
      console.log("ok")
    JS
    run_node_script(script)
  end
end
