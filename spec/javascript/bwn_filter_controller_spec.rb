require "rails_helper"
require "open3"
require "tempfile"

RSpec.describe "bwn_filter_controller" do
  def run_node_script(script)
    Tempfile.create(["bwn-filter-controller", ".js"]) do |file|
      file.write(script)
      file.flush

      stdout, stderr, status = Open3.capture3("node", file.path)
      expect(status).to be_success, [stdout, stderr].reject(&:empty?).join("\n")
    end
  end

  def controller_source_path
    Rails.root.join("app/javascript/controllers/bwn_filter_controller.js")
  end

  it "delegates panel reset to filter#hideHistogramPanel when leaving a BWN state" do
    script = <<~JS
      const fs = require("fs")
      class Controller {}
      const filterStateCurrent = { state: "TX", boil_water_notices_min: "2" }
      const FilterState = {
        get: () => ({ ...filterStateCurrent })
      }
      const hideCalls = []
      const filterController = {
        hideHistogramPanel: (panelId) => hideCalls.push(panelId)
      }
      const filterEl = { id: "filter-root" }
      const checkbox = {
        checked: true,
        disabled: false,
        dataset: { panelId: "panel-total_notices" }
      }
      global.document = {
        addEventListener: (type, callback) => {
          if (type === "filters:changed") global.filtersChanged = callback
        },
        removeEventListener: () => {}
      }

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.BwnFilterController = class extends Controller")
      eval(source)

      const controller = new BwnFilterController()
      controller.bwnStatesValue = ["TX", "OR"]
      controller.tooltipsValue = {}
      controller.element = {
        closest: () => filterEl,
        dataset: { filterParam: "boil_water_notices" }
      }
      controller.application = {
        getControllerForElementAndIdentifier: (el, id) => {
          if (el === filterEl && id === "filter") return filterController
          return null
        }
      }
      controller.checkboxTarget = checkbox
      controller.hasCheckboxTarget = true
      controller.hasLabelTarget = true
      controller.labelTarget = { classList: { toggle: () => {} } }
      controller.hasDisabledTextTarget = true
      controller.disabledTextTarget = { classList: { toggle: () => {} } }
      controller.hasArrowButtonTarget = true
      controller.arrowButtonTarget = { classList: { toggle: () => {} } }
      controller.connect()

      filterStateCurrent.state = "CA"
      global.filtersChanged()

      if (checkbox.checked) throw new Error("expected checkbox unchecked")
      if (hideCalls.length !== 1) throw new Error(`expected hideHistogramPanel once, got ${hideCalls.length}`)
      if (hideCalls[0] !== "panel-total_notices") throw new Error(`expected panel id, got ${hideCalls[0]}`)
    JS

    run_node_script(script)
  end

  it "enables the checkbox and shows the state tooltip when entering a BWN state" do
    script = <<~JS
      const fs = require("fs")
      class Controller {}
      const filterStateCurrent = {}
      const FilterState = {
        get: () => ({ ...filterStateCurrent })
      }
      const checkbox = {
        checked: false,
        disabled: true,
        dataset: { panelId: "panel-total_notices" }
      }
      const stateTooltip = {
        dataset: {},
        classList: { classes: new Set(["hidden"]), add(name) { this.classes.add(name) }, remove(name) { this.classes.delete(name) }, contains(name) { return this.classes.has(name) } }
      }
      global.document = {
        addEventListener: (type, callback) => {
          if (type === "filters:changed") global.filtersChanged = callback
        },
        removeEventListener: () => {}
      }

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.BwnFilterController = class extends Controller")
      eval(source)

      const controller = new BwnFilterController()
      controller.bwnStatesValue = ["TX", "OR"]
      controller.tooltipsValue = { TX: "<p>Texas methodology</p>" }
      controller.element = { closest: () => null, dataset: { filterParam: "boil_water_notices" } }
      controller.application = { getControllerForElementAndIdentifier: () => null }
      controller.checkboxTarget = checkbox
      controller.hasCheckboxTarget = true
      controller.hasLabelTarget = false
      controller.hasDisabledTextTarget = false
      controller.hasArrowButtonTarget = false
      controller.hasStateTooltipTarget = true
      controller.stateTooltipTarget = stateTooltip
      controller.connect()

      filterStateCurrent.state = "TX"
      global.filtersChanged()

      if (checkbox.disabled) throw new Error("expected checkbox enabled")
      if (stateTooltip.classList.contains("hidden")) throw new Error("expected tooltip visible")
      if (!stateTooltip.classList.contains("inline-flex")) throw new Error("expected tooltip inline-flex")
      if (stateTooltip.dataset.tooltipTextValue !== "<p>Texas methodology</p>") {
        throw new Error(`expected TX tooltip text, got ${stateTooltip.dataset.tooltipTextValue}`)
      }
      if (stateTooltip.dataset.tooltipHtmlValue !== "true") throw new Error("expected tooltip html flag true")
      if (stateTooltip.dataset.tooltipInteractiveValue !== "true") throw new Error("expected tooltip interactive flag true")
    JS

    run_node_script(script)
  end

  it "updates the tooltip content when switching between two BWN states" do
    script = <<~JS
      const fs = require("fs")
      class Controller {}
      const filterStateCurrent = { state: "TX" }
      const FilterState = {
        get: () => ({ ...filterStateCurrent })
      }
      const checkbox = {
        checked: false,
        disabled: false,
        dataset: { panelId: "panel-total_notices" }
      }
      const stateTooltip = {
        dataset: {},
        classList: { classes: new Set(), add(name) { this.classes.add(name) }, remove(name) { this.classes.delete(name) }, contains(name) { return this.classes.has(name) } }
      }
      global.document = {
        addEventListener: (type, callback) => {
          if (type === "filters:changed") global.filtersChanged = callback
        },
        removeEventListener: () => {}
      }

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.BwnFilterController = class extends Controller")
      eval(source)

      const controller = new BwnFilterController()
      controller.bwnStatesValue = ["TX", "OR"]
      controller.tooltipsValue = { TX: "<p>Texas methodology</p>", OR: "<p>Oregon methodology</p>" }
      controller.element = { closest: () => null, dataset: { filterParam: "boil_water_notices" } }
      controller.application = { getControllerForElementAndIdentifier: () => null }
      controller.checkboxTarget = checkbox
      controller.hasCheckboxTarget = true
      controller.hasLabelTarget = false
      controller.hasDisabledTextTarget = false
      controller.hasArrowButtonTarget = false
      controller.hasStateTooltipTarget = true
      controller.stateTooltipTarget = stateTooltip
      controller.connect()

      if (stateTooltip.dataset.tooltipTextValue !== "<p>Texas methodology</p>") {
        throw new Error(`expected initial TX tooltip text, got ${stateTooltip.dataset.tooltipTextValue}`)
      }

      filterStateCurrent.state = "OR"
      global.filtersChanged()

      if (stateTooltip.dataset.tooltipTextValue !== "<p>Oregon methodology</p>") {
        throw new Error(`expected OR tooltip text, got ${stateTooltip.dataset.tooltipTextValue}`)
      }
      if (checkbox.disabled) throw new Error("expected checkbox to remain enabled across BWN states")
    JS

    run_node_script(script)
  end

  it "keeps a checked BWN checkbox checked when moving to a different BWN state, same as any other range filter" do
    script = <<~JS
      const fs = require("fs")
      class Controller {}
      const filterStateCurrent = { state: "TX", boil_water_notices_min: "2" }
      const FilterState = { get: () => ({ ...filterStateCurrent }) }
      const hideCalls = []
      const filterController = { hideHistogramPanel: (panelId) => hideCalls.push(panelId) }
      const filterEl = { id: "filter-root" }
      const checkbox = { checked: true, disabled: false, dataset: { panelId: "panel-total_notices" } }
      global.document = {
        addEventListener: (type, callback) => {
          if (type === "filters:changed") global.filtersChanged = callback
        },
        removeEventListener: () => {}
      }

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.BwnFilterController = class extends Controller")
      eval(source)

      const controller = new BwnFilterController()
      controller.bwnStatesValue = ["TX", "NM"]
      controller.tooltipsValue = {}
      controller.element = { closest: () => filterEl, dataset: { filterParam: "boil_water_notices" } }
      controller.application = {
        getControllerForElementAndIdentifier: (el, id) => (el === filterEl && id === "filter") ? filterController : null
      }
      controller.checkboxTarget = checkbox
      controller.hasCheckboxTarget = true
      controller.hasLabelTarget = false
      controller.hasDisabledTextTarget = false
      controller.hasArrowButtonTarget = false
      controller.connect()

      // A state change strips range params before this fires (map_controller#withoutRangeParams),
      // so a checked BWN row sees its own min/max gone too — same as it would for TX -> NM.
      filterStateCurrent.state = "NM"
      delete filterStateCurrent.boil_water_notices_min
      global.filtersChanged()

      if (!checkbox.checked) throw new Error("expected checkbox to stay checked across BWN -> BWN")
      if (checkbox.disabled) throw new Error("expected checkbox to stay enabled in the new BWN state")
      if (hideCalls.length !== 0) throw new Error(`expected the slider panel to stay open, got hideHistogramPanel called ${hideCalls.length} time(s)`)
    JS

    run_node_script(script)
  end
end
