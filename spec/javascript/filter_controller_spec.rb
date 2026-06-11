require "rails_helper"
require "open3"
require "tempfile"

RSpec.describe "filter_controller state preservation" do
  def run_node_script(script)
    Tempfile.create(["filter-controller-state-preservation", ".js"]) do |file|
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
        id: "ws-ground",
        checked: false,
        type: "radio",
        hasAttribute: (name) => name === "data-default"
      }
      const surface = {
        id: "ws-surface",
        checked: false,
        type: "radio",
        hasAttribute: () => false
      }
      elementsById["ws-ground"] = groundwater
      elementsById["ws-surface"] = surface
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
      global.history = { replaceState: () => {} }
      global.window = { location: new URL("http://example.test/") }
      global.Turbo = { visit: (url, options) => visits.push([url, options]) }

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.FilterController = class extends Controller")
      eval(source)

      const controller = new FilterController()
      controller.element = { querySelectorAll: () => [] }
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
      if (!tableVisit[0].includes("state=CO")) throw new Error(`expected table URL to include state, got ${tableVisit[0]}`)
    JS

    run_node_script(script)
  end
end
