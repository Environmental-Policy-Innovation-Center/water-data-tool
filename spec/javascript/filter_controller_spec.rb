require "rails_helper"
require "open3"
require "tempfile"

RSpec.describe "filter_controller state preservation" do
  def run_node_script(script)
    Tempfile.create(["filter-controller-state-preservation", ".js"]) do |file|
      file.write(<<~JS)
        function syncStatsFrame() {
          const frame = document.querySelector("turbo-frame#stats-bar")
          if (!frame) return

          const params = new URLSearchParams(FilterState.toUrlParams())
          const container = document.getElementById("container-map-content-bottom")

          if ([...params.keys()].length === 0) {
            frame.removeAttribute("src")
            frame.innerHTML = ""
            container?.classList.remove("has-stats")
            return
          }

          const newSrc = `/public_water_systems/stats?${params.toString()}`
          if (frame.getAttribute("src") === newSrc) return
          frame.src = newSrc
          container?.classList.add("has-stats")
        }

        const SelectionState = {
          clear: () => { globalThis.selectionClearCount = (globalThis.selectionClearCount || 0) + 1 }
        }
        const decodeState = () => ({})
        const colsFromUrl = () => null
        const sortFromUrl = () => ({ sort: null, direction: null })
        const buildEncodedParam = ({ filters = {}, cols = null } = {}) => {
          const state = {}
          if (Object.keys(filters).length > 0) state.filters = filters
          if (cols !== null) state.cols = cols
          return Buffer.from(JSON.stringify(state)).toString("base64url")
        }

        function syncToUrl() {
          const url = new URL(window.location)
          const filters = FilterState.get()
          url.search = ""
          if (Object.keys(filters).length > 0) {
            url.searchParams.set("encoded", buildEncodedParam({ filters }))
          }
          history.replaceState({}, "", url)
        }
      JS
      file.write(script)
      file.flush

      stdout, stderr, status = Open3.capture3("node", file.path)
      expect(status).to be_success, [stdout, stderr].reject(&:empty?).join("\n")
    end
  end

  def controller_source_path
    Rails.root.join("app/javascript/controllers/filter_controller.js")
  end

  it "preserves selected state params when applying menu filters, resetting all, and reloading the table" do
    script = <<~JS
      const fs = require("fs")
      class Controller {
        dispatch(type) { this.dispatched ||= []; this.dispatched.push(type) }
      }
      const filterStateCurrent = { state: "CO", state_name: "Colorado" }
      const FilterState = {
        get: () => ({ ...filterStateCurrent }),
        set: (params) => {
          Object.keys(filterStateCurrent).forEach((key) => delete filterStateCurrent[key])
          Object.assign(filterStateCurrent, params)
        },
        toUrlParams: () => new URLSearchParams(filterStateCurrent),
        fromUrlParams: () => ({})
      }
      const visits = []
      const listeners = {}
      const elementsById = {}
      const makeClassList = (...classes) => ({
        classes: new Set(classes),
        contains(name) { return this.classes.has(name) },
        add(name) { this.classes.add(name) },
        remove(name) { this.classes.delete(name) },
        toggle(name) {
          if (this.classes.has(name)) {
            this.classes.delete(name)
            return false
          }
          this.classes.add(name)
          return true
        }
      })
      const groundwater = {
        id: "filter-gw_sw_code-groundwater",
        checked: false,
        type: "radio",
        dataset: { filterKind: "radio", filterParam: "gw_sw_code", filterValue: "Groundwater", filterGroup: "1" },
        hasAttribute: (name) => name === "data-default"
      }
      const surface = {
        id: "filter-gw_sw_code-surface-water",
        checked: false,
        type: "radio",
        dataset: { filterKind: "radio", filterParam: "gw_sw_code", filterValue: "Surface Water", filterGroup: "1" },
        hasAttribute: () => false
      }
      elementsById[groundwater.id] = groundwater
      elementsById[surface.id] = surface
      const menu = {
        classList: makeClassList("filter-dropdown"),
        contains: () => false,
        querySelectorAll: (selector) => {
          if (selector === "input[type='radio']") return [groundwater, surface]
          if (selector === "input[type='checkbox']") return []
          return []
        },
        querySelector: () => null
      }
      const statsFrame = {
        attrs: {},
        getAttribute(name) { return this.attrs[name] },
        set src(value) { this.attrs.src = value },
        get src() { return this.attrs.src }
      }
      global.document = {
        addEventListener: (type, callback) => { listeners[type] = callback },
        removeEventListener: () => {},
        dispatchEvent: (event) => { listeners[event.type]?.(event) },
        querySelectorAll: (selector) => selector === ".filter-dropdown" ? [menu] : [],
        querySelector: (selector) => selector === "turbo-frame#stats-bar" ? statsFrame : null,
        getElementById: (id) => elementsById[id] || null
      }
      global.CustomEvent = class {
        constructor(type) { this.type = type }
      }
      global.window = { location: new URL("http://example.test/") }
      global.history = {
        replaceState: (_state, _title, url) => {
          window.location = new URL(url, window.location)
        }
      }
      global.Turbo = { visit: (url, options) => visits.push([url, options]) }

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.FilterController = class extends Controller")
      eval(source)

      const controller = new FilterController()
      controller.element = {
        querySelectorAll: (selector) => selector === "[data-filter-kind]" ? [groundwater, surface] : [],
        querySelector: () => null
      }
      controller.application = { getControllerForElementAndIdentifier: () => null }
      controller.connect()

      surface.checked = true
      controller.apply({ preventDefault: () => {} })
      if (filterStateCurrent.state !== "CO") throw new Error("expected apply to preserve state")
      if (filterStateCurrent.state_name !== "Colorado") throw new Error("expected apply to preserve state_name")
      if (filterStateCurrent.gw_sw_code !== "Surface Water") throw new Error(`expected applied menu filter, got ${filterStateCurrent.gw_sw_code}`)

      controller.resetAll({ preventDefault: () => {} })
      if (filterStateCurrent.state !== "CO") throw new Error("expected resetAll to preserve state")
      if (filterStateCurrent.state_name !== "Colorado") throw new Error("expected resetAll to preserve state_name")
      if (filterStateCurrent.gw_sw_code !== "Groundwater") throw new Error(`expected resetAll to restore default menu filter, got ${filterStateCurrent.gw_sw_code}`)

      document.dispatchEvent(new CustomEvent("table:show"))
      controller.apply({ preventDefault: () => {} })
      const tableVisit = visits.at(-1)
      if (!tableVisit) throw new Error("expected table reload visit")
      const tableUrl = new URL(tableVisit[0], "http://example.test")
      const encoded = tableUrl.searchParams.get("encoded")
      if (!encoded) throw new Error(`expected table URL to include encoded filters, got ${tableVisit[0]}`)
      const decoded = JSON.parse(Buffer.from(encoded, "base64url").toString())
      if (decoded.filters.state !== "CO") throw new Error(`expected table URL to preserve state, got ${tableVisit[0]}`)
    JS

    run_node_script(script)
  end

  it "clears the stats frame when applying an empty filter state" do
    script = <<~JS
      const fs = require("fs")
      class Controller {
        dispatch(type) { this.dispatched ||= []; this.dispatched.push(type) }
      }
      const filterStateCurrent = {}
      const FilterState = {
        get: () => ({ ...filterStateCurrent }),
        set: (params) => {
          Object.keys(filterStateCurrent).forEach((key) => delete filterStateCurrent[key])
          Object.assign(filterStateCurrent, params)
        },
        toUrlParams: () => new URLSearchParams(filterStateCurrent),
        fromUrlParams: () => ({})
      }
      const statsContainerClasses = new Set(["has-stats"])
      const statsFrame = {
        attrs: { src: "/public_water_systems/stats?gw_sw_code=Groundwater" },
        innerHTML: "<div>old stats</div>",
        getAttribute(name) { return this.attrs[name] },
        removeAttribute(name) { delete this.attrs[name] },
        set src(value) { this.attrs.src = value },
        get src() { return this.attrs.src }
      }
      global.document = {
        addEventListener: () => {},
        removeEventListener: () => {},
        dispatchEvent: () => {},
        querySelectorAll: () => [],
        querySelector: (selector) => selector === "turbo-frame#stats-bar" ? statsFrame : null,
        getElementById: (id) => {
          if (id === "container-map-content-bottom") {
            return {
              classList: {
                add: (name) => statsContainerClasses.add(name),
                remove: (name) => statsContainerClasses.delete(name)
              }
            }
          }
          return null
        }
      }
      global.CustomEvent = class {
        constructor(type) { this.type = type }
      }
      global.history = { replaceState: () => {} }
      global.window = { location: new URL("http://example.test/") }
      global.Turbo = { visit: () => {} }

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.FilterController = class extends Controller")
      eval(source)

      const controller = new FilterController()
      controller.element = { querySelectorAll: () => [] }
      controller.application = { getControllerForElementAndIdentifier: () => null }
      controller.connect()
      controller.apply({ preventDefault: () => {} })

      if (statsFrame.getAttribute("src") != null) throw new Error(`expected stats src to be cleared, got ${statsFrame.getAttribute("src")}`)
      if (statsFrame.innerHTML !== "") throw new Error(`expected stats html to be cleared, got ${statsFrame.innerHTML}`)
      if (statsContainerClasses.has("has-stats")) throw new Error("expected stats container class to be removed")
    JS

    run_node_script(script)
  end

  it "refreshes checked range filter defaults when the state scope changes" do
    script = <<~JS
      const fs = require("fs")
      class Controller {
        dispatch(type) { this.dispatched ||= []; this.dispatched.push(type) }
      }
      const filterStateCurrent = { state: "TX", boil_water_notices_min: "1", boil_water_notices_max: "45" }
      const FilterState = {
        get: () => ({ ...filterStateCurrent }),
        set: (params) => {
          Object.keys(filterStateCurrent).forEach((key) => delete filterStateCurrent[key])
          Object.assign(filterStateCurrent, params)
        },
        toUrlParams: () => new URLSearchParams(filterStateCurrent),
        fromUrlParams: () => ({})
      }
      const populateCalls = []
      const boilWaterCheckbox = { checked: true, disabled: false }
      const panel = {
        id: "panel-total_notices",
        classList: { contains: (name) => name === "hidden" },
        dataset: { sliderFieldValue: "total_notices" }
      }
      const rangeEl = {
        dataset: { filterKind: "range", filterParam: "boil_water_notices" },
        querySelector: (sel) => {
          if (sel === "input[type='checkbox']") return boilWaterCheckbox
          if (sel === "[data-slider-field-value]") return panel
          return null
        }
      }
      const listeners = {}
      global.document = {
        addEventListener: (type, callback) => { listeners[type] = callback },
        removeEventListener: () => {},
        dispatchEvent: (event) => { listeners[event.type]?.(event) },
        querySelectorAll: () => [],
        querySelector: () => null,
        getElementById: () => null
      }
      global.CustomEvent = class {
        constructor(type) { this.type = type }
      }
      global.history = { replaceState: () => {} }
      global.window = { location: new URL("http://example.test/") }
      const visits = []
      global.Turbo = { visit: (url, options) => visits.push([url, options]) }

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.FilterController = class extends Controller")
      eval(source)

      const controller = new FilterController()
      controller.element = {
        querySelectorAll: (sel) => sel === "[data-filter-kind='range']" ? [rangeEl] : []
      }
      controller.application = {
        getControllerForElementAndIdentifier: (_panel, identifier) => {
          if (identifier !== "slider") return null
          return { populateDefaultsIfEmpty: () => populateCalls.push("slider") }
        }
      }
      controller.connect()

      // Table already shown — a state change should refresh it immediately (not just the
      // eventual re-sync once a checked range filter's fresh defaults resolve), same as it
      // already refreshes badges and the geo title.
      document.dispatchEvent(new CustomEvent("table:show"))
      visits.length = 0

      delete filterStateCurrent.boil_water_notices_min
      delete filterStateCurrent.boil_water_notices_max
      filterStateCurrent.state = "OR"
      document.dispatchEvent(new CustomEvent("filters:changed"))

      if (populateCalls.length !== 1) throw new Error(`expected one slider refresh, got ${populateCalls.length}`)
      if (visits.length !== 1) throw new Error(`expected the table to reload once on the state change, got ${visits.length}`)
    JS

    run_node_script(script)
  end

  it "syncs FilterState from hidden inputs after slider:state-reload" do
    script = <<~JS
      const fs = require("fs")
      class Controller {
        dispatch(type) { this.dispatched ||= []; this.dispatched.push(type) }
      }
      const filterStateCurrent = { state: "TX" }
      global.FilterState = {
        get: () => ({ ...filterStateCurrent }),
        set: (params) => {
          Object.keys(filterStateCurrent).forEach((key) => delete filterStateCurrent[key])
          Object.assign(filterStateCurrent, params)
        },
        toUrlParams: () => new URLSearchParams(filterStateCurrent),
        fromUrlParams: () => ({})
      }
      const minInput = { value: "1" }
      const maxInput = { value: "500" }
      const sliderPanel = {
        dataset: { sliderFieldValue: "total_notices" },
        querySelector: (sel) => {
          if (sel === "[data-slider-target='minInput']") return minInput
          if (sel === "[data-slider-target='maxInput']") return maxInput
          return null
        }
      }
      const rangeEl = {
        dataset: { filterKind: "range", filterParam: "boil_water_notices" },
        querySelector: (sel) => {
          if (sel === "input[type='checkbox']") return { checked: true }
          if (sel === "[data-slider-field-value]") return sliderPanel
          return null
        }
      }
      const listeners = {}
      const dispatchedTypes = []
      global.document = {
        addEventListener: (type, callback) => { listeners[type] = callback },
        removeEventListener: () => {},
        dispatchEvent: (event) => {
          dispatchedTypes.push(event.type)
          listeners[event.type]?.(event)
        },
        querySelectorAll: () => [],
        querySelector: () => null,
        getElementById: () => null
      }
      global.CustomEvent = class {
        constructor(type) { this.type = type }
      }
      global.window = { location: new URL("http://example.test/") }
      global.history = {
        replaceState: (_state, _title, url) => {
          window.location = new URL(url, window.location)
        }
      }
      const visits = []
      global.Turbo = { visit: (url, options) => visits.push([url, options]) }

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.FilterController = class extends Controller")
      eval(source)

      const controller = new FilterController()
      controller.element = {
        querySelectorAll: (sel) => sel === "[data-filter-kind='range']" ? [rangeEl] : []
      }
      controller.application = { getControllerForElementAndIdentifier: () => null }
      controller.connect()

      // Table already shown (as it would be if the user had switched to Table view) —
      // the restored range params should reach it, not just the URL/FilterState.
      document.dispatchEvent(new CustomEvent("table:show"))
      dispatchedTypes.length = 0
      visits.length = 0

      document.dispatchEvent(new CustomEvent("slider:state-reload"))
      await new Promise((resolve) => setTimeout(resolve, 60))

      if (filterStateCurrent.boil_water_notices_min !== "1") {
        throw new Error(`expected min 1 in FilterState, got ${filterStateCurrent.boil_water_notices_min}`)
      }
      if (filterStateCurrent.boil_water_notices_max !== "500") {
        throw new Error(`expected max 500 in FilterState, got ${filterStateCurrent.boil_water_notices_max}`)
      }

      // The whole point of restoring these params is that the map and table actually pick
      // them up — not just the URL. Re-dispatching filters:changed is what makes the map's
      // own listener re-fetch; reloading the table frame is what makes Table view catch up.
      if (!dispatchedTypes.includes("filters:changed")) {
        throw new Error("expected slider:state-reload settling to re-dispatch filters:changed so the map re-syncs")
      }
      if (visits.length !== 1) {
        throw new Error(`expected exactly one table reload visit once params settled, got ${visits.length}`)
      }
      const visitUrl = new URL(visits[0][0], "http://example.test")
      const encoded = visitUrl.searchParams.get("encoded")
      const decoded = JSON.parse(Buffer.from(encoded, "base64url").toString())
      if (decoded.filters.boil_water_notices_min !== "1") {
        throw new Error(`expected table reload URL to carry the restored range params, got ${visits[0][0]}`)
      }
    JS

    run_node_script("(async () => { #{script} })()")
  end

  it "hideHistogramPanel hides the panel and resets the slider" do
    script = <<~JS
      const fs = require("fs")
      class Controller {
        dispatch(type) { this.dispatched ||= []; this.dispatched.push(type) }
      }
      const resetCalls = []
      const panel = {
        id: "panel-total_notices",
        classList: { classes: new Set(), contains() { return this.classes.has("hidden") }, add(name) { this.classes.add(name) } },
        querySelectorAll: () => [{ value: "1" }, { value: "45" }]
      }
      const arrowBtn = {
        dataset: { panelId: "panel-total_notices" },
        setAttribute: () => {},
        querySelector: () => ({ classList: { toggle: () => {} } })
      }
      global.document = {
        addEventListener: () => {},
        removeEventListener: () => {},
        dispatchEvent: () => {},
        querySelectorAll: () => [],
        querySelector: (selector) => selector.includes("panel-total_notices") ? arrowBtn : null,
        getElementById: (id) => id === "panel-total_notices" ? panel : null
      }
      global.CustomEvent = class {
        constructor(type) { this.type = type }
      }
      global.history = { replaceState: () => {} }
      global.window = { location: new URL("http://example.test/") }
      global.Turbo = { visit: () => {} }
      const FilterState = {
        get: () => ({}),
        set: () => {},
        toUrlParams: () => new URLSearchParams(),
        fromUrlParams: () => ({})
      }

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.FilterController = class extends Controller")
      eval(source)

      const controller = new FilterController()
      controller.element = {
        querySelectorAll: (selector) => selector === "[data-subcat-panel]" ? [] : [arrowBtn],
        querySelector: () => arrowBtn
      }
      controller.application = {
        getControllerForElementAndIdentifier: (_el, id) => id === "slider" ? { resetToFullRange: () => resetCalls.push("reset") } : null
      }
      controller.connect()

      controller.hideHistogramPanel("panel-total_notices")

      if (!panel.classList.classes.has("hidden")) throw new Error("expected panel hidden")
      if (resetCalls.length !== 1) throw new Error(`expected slider reset, got ${resetCalls.length}`)
    JS

    run_node_script(script)
  end

  it "recomputes subcat parent checked/indeterminate state on connect (hard refresh / shared URL restore)" do
    script = <<~JS
      const fs = require("fs")
      class Controller {
        dispatch(type) { this.dispatched ||= []; this.dispatched.push(type) }
      }
      const FilterState = {
        get: () => ({}),
        set: () => {},
        toUrlParams: () => new URLSearchParams(),
        fromUrlParams: () => ({})
      }
      global.document = {
        addEventListener: () => {},
        removeEventListener: () => {},
        dispatchEvent: () => {},
        querySelectorAll: () => [],
        querySelector: () => null,
        getElementById: () => null
      }
      global.CustomEvent = class {
        constructor(type) { this.type = type }
      }
      global.history = { replaceState: () => {} }
      global.window = { location: new URL("http://example.test/") }
      global.Turbo = { visit: () => {} }
      global.CSS = { escape: (s) => s }

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.FilterController = class extends Controller")
      eval(source)

      // Simulates a server-rendered "Health violations (5yr)" subcat parent panel restored from a
      // shared URL where only one of ten sub-filters (e.g. groundwater_rule_5yr) is active — the
      // parent checkbox should show indeterminate, not flatly unchecked, since syncParentFromSubcat
      // only reacts to a live change event that never fires on page load.
      const parentCheckbox = { checked: false, indeterminate: false }
      const activeRow = { querySelector: () => ({ checked: true }) }
      const inactiveRows = Array.from({length: 9}, () => ({ querySelector: () => ({ checked: false }) }))
      const subcatPanel = {
        id: "panel-health_5yr",
        querySelectorAll: (selector) => selector === "[data-filter-kind='range']" ? [activeRow, ...inactiveRows] : []
      }

      const controller = new FilterController()
      controller.element = {
        querySelectorAll: (selector) => selector === "[data-subcat-panel]" ? [subcatPanel] : [],
        querySelector: (selector) => selector.includes("panel-health_5yr") ? parentCheckbox : null
      }
      controller.application = { getControllerForElementAndIdentifier: () => null }
      controller.connect()

      if (parentCheckbox.checked) throw new Error("expected parent checkbox not fully checked")
      if (!parentCheckbox.indeterminate) throw new Error("expected parent checkbox indeterminate")
    JS

    run_node_script(script)
  end
end
