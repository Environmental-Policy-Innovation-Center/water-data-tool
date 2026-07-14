require "rails_helper"
require "open3"
require "tempfile"

RSpec.describe "slider_controller state reload" do
  def run_node_script(script)
    Tempfile.create(["slider-controller-state-reload", ".js"]) do |file|
      file.write(script)
      file.flush

      stdout, stderr, status = Open3.capture3("node", file.path)
      expect(status).to be_success, [stdout, stderr].reject(&:empty?).join("\n")
    end
  end

  def controller_source_path
    Rails.root.join("app/javascript/controllers/slider_controller.js")
  end

  def document_stub_js
    <<~JS
      const makeSvgEl = (tag) => ({
        tagName: tag,
        attrs: {},
        dataset: {},
        style: { display: "" },
        textContent: "",
        setAttribute(k, v) {
          this.attrs[k] = String(v)
          if (k.startsWith("data-")) {
            const key = k.slice(5).replace(/-([a-z])/g, (_, c) => c.toUpperCase())
            this.dataset[key] = String(v)
          }
        },
        getAttribute(k) { return this.attrs[k] },
        remove() {},
        appendChild() {},
        addEventListener: () => {},
        removeEventListener: () => {}
      })
      const documentStub = {
        addEventListener: (type, callback) => {
          if (type === "filters:changed") global.filtersChanged = callback
        },
        removeEventListener: () => {},
        dispatchEvent: (event) => { dispatchedEvents.push(event.type) },
        createElementNS: (_ns, tag) => makeSvgEl(tag)
      }
    JS
  end

  it "resets text inputs and repopulates hidden defaults after a state change reload" do
    script = <<~JS
      const fs = require("fs")
      class Controller {}
      const filterStateCurrent = { state: "TX" }
      const FilterState = {
        get: () => ({ ...filterStateCurrent }),
        set: (params) => {
          Object.keys(filterStateCurrent).forEach((key) => delete filterStateCurrent[key])
          Object.assign(filterStateCurrent, params)
        }
      }
      const dispatchedEvents = []
      const fetchCalls = []
      global.fetch = (url) => {
        fetchCalls.push(String(url))
        const state = new URL(url, "http://example.test").searchParams.get("state") || "national"
        const domainMax = state === "OR" ? 500 : 45
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve({
            bins: [{ min: 1, max: 2, count: 1 }],
            domain_min: 1,
            domain_max: domainMax
          })
        })
      }
      #{document_stub_js}
      global.document = documentStub
      global.CustomEvent = class {
        constructor(type, options = {}) {
          this.type = type
          this.bubbles = options.bubbles
        }
      }
      global.ResizeObserver = class {
        observe() {}
        disconnect() {}
      }

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.SliderController = class extends Controller")
      eval(source)

      const chart = {
        _children: [],
        get firstChild() { return this._children[0] || null },
        removeChild(node) {
          this._children = this._children.filter((child) => child !== node)
        },
        appendChild(node) {
          node.remove = () => {
            this._children = this._children.filter((child) => child !== node)
          }
          this._children.push(node)
        },
        setAttribute() {},
        classList: { toggle() {} },
        innerHTML: "",
        getBoundingClientRect: () => ({ left: 0, width: 400 }),
        addEventListener: () => {},
        removeEventListener: () => {}
      }
      const minInput = { value: "" }
      const maxInput = { value: "" }
      const minTextInput = { value: "" }
      const maxTextInput = { value: "" }

      const controller = new SliderController()
      controller.element = {
        classList: { contains: () => false },
        dispatchEvent: (event) => { dispatchedEvents.push(event.type) }
      }
      controller.fieldValue = "total_notices"
      controller.urlValue = "/histogram"
      controller.formatValue = "count"
      controller.chartTarget = chart
      controller.minInputTarget = minInput
      controller.maxInputTarget = maxInput
      controller.minTextInputTarget = minTextInput
      controller.maxTextInputTarget = maxTextInput
      controller.minLabelTarget = { textContent: "" }
      controller.maxLabelTarget = { textContent: "" }
      controller.hasMinTextInputTarget = true
      controller.hasMaxTextInputTarget = true
      controller.hasZeroLabelTarget = false
      controller.connect()

      await controller.load()
      if (String(maxInput.value) !== "45" && String(maxInput.value) !== "1") {
        throw new Error(`expected initial load to populate hidden max, got ${maxInput.value}`)
      }

      minInput.value = "10"
      maxInput.value = "40"
      minTextInput.value = "10"
      maxTextInput.value = "40"

      filterStateCurrent.state = "OR"
      global.filtersChanged()
      await controller.load()

      if (minTextInput.value !== "") throw new Error(`expected empty min text input, got ${minTextInput.value}`)
      if (maxTextInput.value !== "") throw new Error(`expected empty max text input, got ${maxTextInput.value}`)
      if (String(minInput.value) !== "1") throw new Error(`expected hidden min default 1, got ${minInput.value}`)
      if (String(maxInput.value) !== "500") throw new Error(`expected hidden max default 500, got ${maxInput.value}`)
      if (!fetchCalls.some((url) => url.includes("state=OR"))) throw new Error("expected OR histogram fetch")
      if (!dispatchedEvents.includes("slider:state-reload")) throw new Error("expected slider:state-reload event")
    JS

    run_node_script("(async () => { #{script} })()")
  end

  it "does not extend small count-domain histograms (few discrete integer values) beyond domain_max" do
    script = <<~JS
      const fs = require("fs")
      class Controller {}
      const FilterState = { get: () => ({ state: "TX" }) }
      const dispatchedEvents = []
      global.fetch = () => Promise.resolve({
        ok: true,
        json: () => Promise.resolve({
          bins: [{ min: 1, max: 2, count: 1 }],
          domain_min: 1,
          domain_max: 45
        })
      })
      #{document_stub_js}
      global.document = documentStub
      global.CustomEvent = class {
        constructor(type) { this.type = type }
      }
      global.ResizeObserver = class {
        observe() {}
        disconnect() {}
      }

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.SliderController = class extends Controller")
      eval(source)

      const maxInput = { value: "" }
      const controller = new SliderController()
      controller.element = { classList: { contains: () => false }, dispatchEvent: () => {} }
      controller.fieldValue = "total_notices"
      controller.urlValue = "/histogram"
      controller.formatValue = "count"
      controller.chartTarget = {
        _children: [],
        get firstChild() { return this._children[0] || null },
        removeChild(node) {
          this._children = this._children.filter((child) => child !== node)
        },
        appendChild(node) {
          node.remove = () => {
            this._children = this._children.filter((child) => child !== node)
          }
          this._children.push(node)
        },
        setAttribute() {},
        classList: { toggle() {} },
        innerHTML: "",
        getBoundingClientRect: () => ({ left: 0, width: 400 }),
        addEventListener: () => {},
        removeEventListener: () => {}
      }
      controller.minInputTarget = { value: "" }
      controller.maxInputTarget = maxInput
      controller.minTextInputTarget = { value: "" }
      controller.maxTextInputTarget = { value: "" }
      controller.minLabelTarget = { textContent: "" }
      controller.maxLabelTarget = { textContent: "" }
      controller.hasMinTextInputTarget = true
      controller.hasMaxTextInputTarget = true
      controller.hasZeroLabelTarget = false
      controller.connect()

      await controller.load()
      if (String(maxInput.value) !== "45") throw new Error(`expected hidden max 45, got ${maxInput.value}`)
    JS

    run_node_script("(async () => { #{script} })()")
  end

  it "extends large count-domain histograms to a nice round max, same as currency" do
    script = <<~JS
      const fs = require("fs")
      class Controller {}
      const FilterState = { get: () => ({ state: "" }) }
      global.fetch = () => Promise.resolve({
        ok: true,
        json: () => Promise.resolve({
          bins: Array.from({length: 30}, (_, i) => ({min: i, max: i + 1, count: 1})),
          domain_min: 1,
          domain_max: 2254
        })
      })
      #{document_stub_js}
      global.document = documentStub
      global.CustomEvent = class {
        constructor(type) { this.type = type }
      }
      global.ResizeObserver = class {
        observe() {}
        disconnect() {}
      }

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.SliderController = class extends Controller")
      eval(source)

      const maxInput = { value: "" }
      const controller = new SliderController()
      controller.element = { classList: { contains: () => false }, dispatchEvent: () => {} }
      controller.fieldValue = "groundwater_rule_10yr"
      controller.urlValue = "/histogram"
      controller.formatValue = "count"
      controller.chartTarget = {
        _children: [],
        get firstChild() { return this._children[0] || null },
        removeChild(node) {
          this._children = this._children.filter((child) => child !== node)
        },
        appendChild(node) {
          node.remove = () => {
            this._children = this._children.filter((child) => child !== node)
          }
          this._children.push(node)
        },
        setAttribute() {},
        classList: { toggle() {} },
        innerHTML: "",
        getBoundingClientRect: () => ({ left: 0, width: 400 }),
        addEventListener: () => {},
        removeEventListener: () => {}
      }
      controller.minInputTarget = { value: "" }
      controller.maxInputTarget = maxInput
      controller.minTextInputTarget = { value: "" }
      controller.maxTextInputTarget = { value: "" }
      controller.minLabelTarget = { textContent: "" }
      controller.maxLabelTarget = { textContent: "" }
      controller.hasMinTextInputTarget = true
      controller.hasMaxTextInputTarget = true
      controller.hasZeroLabelTarget = false
      controller.connect()

      await controller.load()
      if (String(maxInput.value) !== "2500") throw new Error(`expected nice-rounded max 2500, got ${maxInput.value}`)
    JS

    run_node_script("(async () => { #{script} })()")
  end

  it "keeps a single-value histogram bar blue after a no-op interaction, not grey" do
    script = <<~JS
      const fs = require("fs")
      class Controller {}
      const FilterState = { get: () => ({ state: "TX" }) }
      global.fetch = () => Promise.resolve({
        ok: true,
        json: () => Promise.resolve({
          bins: [{ min: 1, max: 2, count: 12 }],
          domain_min: 1,
          domain_max: 1
        })
      })
      #{document_stub_js}
      global.document = documentStub
      global.CustomEvent = class {
        constructor(type) { this.type = type }
      }
      global.ResizeObserver = class {
        constructor(cb) { this.cb = cb }
        observe() { this.cb([{ contentRect: { width: 400 } }]) }
        disconnect() {}
      }

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.SliderController = class extends Controller")
      eval(source)

      const controller = new SliderController()
      controller.element = { classList: { contains: () => false }, dispatchEvent: () => {} }
      controller.fieldValue = "groundwater_rule_5yr"
      controller.urlValue = "/histogram"
      controller.formatValue = "count"
      controller.chartTarget = {
        _children: [],
        get firstChild() { return this._children[0] || null },
        removeChild(node) {
          this._children = this._children.filter((child) => child !== node)
        },
        appendChild(node) {
          node.remove = () => {
            this._children = this._children.filter((child) => child !== node)
          }
          this._children.push(node)
        },
        setAttribute() {},
        classList: { toggle() {} },
        innerHTML: "",
        getBoundingClientRect: () => ({ left: 0, width: 400 }),
        addEventListener: () => {},
        removeEventListener: () => {}
      }
      controller.minInputTarget = { value: "" }
      controller.maxInputTarget = { value: "" }
      controller.minTextInputTarget = { value: "" }
      controller.maxTextInputTarget = { value: "" }
      controller.minLabelTarget = { textContent: "" }
      controller.maxLabelTarget = { textContent: "" }
      controller.hasMinTextInputTarget = true
      controller.hasMaxTextInputTarget = true
      controller.hasZeroLabelTarget = false
      controller.connect()

      await controller.load()

      // Click into (and out of) the min text input without typing anything — a no-op that
      // still runs #onTextChange's empty-raw branch, which calls #colorBars().
      controller.textInputChanged({ type: "change", currentTarget: controller.minTextInputTarget })

      const bar = controller.chartTarget._children.find((c) => c.tagName === "path")
      if (!bar) throw new Error("expected a bar path to be rendered")
      if (bar.attrs.fill !== "#3B82F6") throw new Error(`expected bar to stay blue, got fill ${bar.attrs.fill}`)
    JS

    run_node_script("(async () => { #{script} })()")
  end

  it "shows a restored min/max value explicitly, but blanks one that lands on the domain edge (a no-op filter)" do
    script = <<~JS
      const fs = require("fs")
      class Controller {}
      const FilterState = { get: () => ({ state: "TX" }) }
      global.fetch = () => Promise.resolve({
        ok: true,
        json: () => Promise.resolve({
          bins: [{ min: 1, max: 2, count: 1 }],
          domain_min: 1,
          domain_max: 45
        })
      })
      #{document_stub_js}
      global.document = documentStub
      global.CustomEvent = class {
        constructor(type) { this.type = type }
      }
      global.ResizeObserver = class {
        observe() {}
        disconnect() {}
      }

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.SliderController = class extends Controller")
      eval(source)

      // Simulates a fresh tab opened from a bookmarked URL where the server rendered
      // min="1" (the domain floor, a no-op filter) and max="20" (a real constraint)
      // from the decoded filter params.
      const minTextInput = { value: "" }
      const maxTextInput = { value: "" }
      const controller = new SliderController()
      controller.element = { classList: { contains: () => false }, dispatchEvent: () => {} }
      controller.fieldValue = "total_notices"
      controller.urlValue = "/histogram"
      controller.formatValue = "count"
      controller.chartTarget = {
        _children: [],
        get firstChild() { return this._children[0] || null },
        removeChild(node) {
          this._children = this._children.filter((child) => child !== node)
        },
        appendChild(node) {
          node.remove = () => {
            this._children = this._children.filter((child) => child !== node)
          }
          this._children.push(node)
        },
        setAttribute() {},
        classList: { toggle() {} },
        innerHTML: "",
        getBoundingClientRect: () => ({ left: 0, width: 400 }),
        addEventListener: () => {},
        removeEventListener: () => {}
      }
      controller.minInputTarget = { value: "1" }
      controller.maxInputTarget = { value: "20" }
      controller.minTextInputTarget = minTextInput
      controller.maxTextInputTarget = maxTextInput
      controller.minLabelTarget = { textContent: "" }
      controller.maxLabelTarget = { textContent: "" }
      controller.hasMinTextInputTarget = true
      controller.hasMaxTextInputTarget = true
      controller.hasZeroLabelTarget = false
      controller.connect()

      await controller.load()
      if (minTextInput.value !== "") throw new Error(`expected blank min text (domain-edge, no-op filter), got ${JSON.stringify(minTextInput.value)}`)
      if (maxTextInput.value !== "20") throw new Error(`expected visible max text to show "20", got ${JSON.stringify(maxTextInput.value)}`)
    JS

    run_node_script("(async () => { #{script} })()")
  end

  it "does not loop forever when a state-scoped histogram legitimately returns zero bins" do
    script = <<~JS
      const fs = require("fs")
      class Controller {}
      const filterStateCurrent = { state: "TX" }
      const FilterState = {
        get: () => ({ ...filterStateCurrent }),
        set: (params) => {
          Object.keys(filterStateCurrent).forEach((key) => delete filterStateCurrent[key])
          Object.assign(filterStateCurrent, params)
        }
      }
      const dispatchedEvents = []
      global.fetch = (url) => {
        const state = new URL(url, "http://example.test").searchParams.get("state") || ""
        const body = state === "NM"
          ? { bins: [], domain_min: 0, domain_max: 0 }
          : { bins: [{ min: 1, max: 2, count: 1 }], domain_min: 1, domain_max: 45 }
        return Promise.resolve({ ok: true, json: () => Promise.resolve(body) })
      }
      #{document_stub_js}
      global.document = documentStub
      global.CustomEvent = class {
        constructor(type, options = {}) {
          this.type = type
          this.bubbles = options.bubbles
        }
      }
      global.ResizeObserver = class {
        observe() {}
        disconnect() {}
      }

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.SliderController = class extends Controller")
      eval(source)

      // A field with zero matching rows in the selected state (a legitimate, final result) must
      // not be confused with "not loaded yet" — that confusion previously caused an unbounded
      // load->init->populateDefaultsIfEmpty->load cycle. Cap draws and fail loudly instead of
      // hanging if that regresses.
      const MAX_DRAWS = 25
      let drawCount = 0
      const chart = {
        _children: [],
        get firstChild() { return this._children[0] || null },
        removeChild(node) {
          this._children = this._children.filter((child) => child !== node)
        },
        appendChild(node) {
          node.remove = () => {
            this._children = this._children.filter((child) => child !== node)
          }
          this._children.push(node)
        },
        setAttribute(key) {
          if (key !== "viewBox") return
          drawCount++
          if (drawCount > MAX_DRAWS) {
            throw new Error(`chart redrawn ${drawCount} times after a zero-bin state reload — looks like an infinite loop`)
          }
        },
        classList: { toggle() {} },
        innerHTML: "",
        getBoundingClientRect: () => ({ left: 0, width: 400 }),
        addEventListener: () => {},
        removeEventListener: () => {}
      }

      const controller = new SliderController()
      controller.element = {
        classList: { contains: () => false },
        dispatchEvent: (event) => { dispatchedEvents.push(event.type) }
      }
      controller.fieldValue = "synthetic_organic_chemicals_5yr"
      controller.urlValue = "/histogram"
      controller.formatValue = "count"
      controller.chartTarget = chart
      controller.minInputTarget = { value: "" }
      controller.maxInputTarget = { value: "" }
      controller.minTextInputTarget = { value: "" }
      controller.maxTextInputTarget = { value: "" }
      controller.minLabelTarget = { textContent: "" }
      controller.maxLabelTarget = { textContent: "" }
      controller.hasMinTextInputTarget = true
      controller.hasMaxTextInputTarget = true
      controller.hasZeroLabelTarget = false
      controller.connect()

      await controller.load()

      filterStateCurrent.state = "NM"
      global.filtersChanged()
      await controller.load()

      for (let i = 0; i < 50; i++) await null

      if (drawCount !== 2) throw new Error(`expected exactly 2 draws (initial load + one zero-bin state reload), got ${drawCount}`)

      // Regression: a zero-bin state must not "stick" and swallow the next transition back
      // to a state with real data — #bins.length can't be trusted to gate the reload trigger
      // since a legitimate zero-bin result also leaves #bins empty. This relies solely on the
      // panel's own filters:changed handler (no explicit controller.load() call here) since a
      // real, still-open panel has no other path back to fresh data.
      filterStateCurrent.state = "TX"
      global.filtersChanged()

      for (let i = 0; i < 50; i++) await null

      if (drawCount !== 3) throw new Error(`expected a third draw after the panel's own state-change handler reloads TX (zero-bin state must not swallow the next transition), got ${drawCount}`)
    JS

    run_node_script("(async () => { #{script} })()")
  end

  it "disables manual min/max entry when the field has no data for the current scope, and re-enables it once real data appears" do
    script = <<~JS
      const fs = require("fs")
      class Controller {}
      const filterStateCurrent = { state: "OK" }
      const FilterState = {
        get: () => ({ ...filterStateCurrent }),
        set: (params) => {
          Object.keys(filterStateCurrent).forEach((key) => delete filterStateCurrent[key])
          Object.assign(filterStateCurrent, params)
        }
      }
      global.fetch = (url) => {
        const state = new URL(url, "http://example.test").searchParams.get("state") || ""
        const body = state === "OK"
          ? { bins: [], domain_min: 0, domain_max: 0 }
          : { bins: [{ min: 1, max: 2, count: 12 }], domain_min: 1, domain_max: 45 }
        return Promise.resolve({ ok: true, json: () => Promise.resolve(body) })
      }
      #{document_stub_js}
      global.document = documentStub
      global.CustomEvent = class {
        constructor(type) { this.type = type }
      }
      global.ResizeObserver = class {
        observe() {}
        disconnect() {}
      }

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.SliderController = class extends Controller")
      eval(source)

      const controller = new SliderController()
      controller.element = { classList: { contains: () => false }, dispatchEvent: () => {} }
      controller.fieldValue = "groundwater_rule_5yr"
      controller.urlValue = "/histogram"
      controller.formatValue = "count"
      controller.chartTarget = {
        _children: [],
        get firstChild() { return this._children[0] || null },
        removeChild(node) { this._children = this._children.filter((child) => child !== node) },
        appendChild(node) {
          node.remove = () => { this._children = this._children.filter((child) => child !== node) }
          this._children.push(node)
        },
        setAttribute() {},
        classList: { toggle() {} },
        innerHTML: "",
        getBoundingClientRect: () => ({ left: 0, width: 400 }),
        addEventListener: () => {},
        removeEventListener: () => {}
      }
      controller.minInputTarget = { value: "" }
      controller.maxInputTarget = { value: "" }
      controller.minTextInputTarget = { value: "", disabled: false, placeholder: "Enter Min" }
      controller.maxTextInputTarget = { value: "", disabled: false, placeholder: "Enter Max" }
      controller.minLabelTarget = { textContent: "" }
      controller.maxLabelTarget = { textContent: "" }
      controller.hasMinTextInputTarget = true
      controller.hasMaxTextInputTarget = true
      controller.hasZeroLabelTarget = false
      controller.connect()

      await controller.load()

      if (!controller.minTextInputTarget.disabled) throw new Error("expected min input disabled when field has no data")
      if (!controller.maxTextInputTarget.disabled) throw new Error("expected max input disabled when field has no data")
      if (controller.minTextInputTarget.placeholder !== "No data") throw new Error(`expected "No data" placeholder, got ${controller.minTextInputTarget.placeholder}`)

      // A state where this field does have data must re-enable the inputs and restore the
      // original placeholder text.
      filterStateCurrent.state = "TX"
      global.filtersChanged()
      await controller.load()

      if (controller.minTextInputTarget.disabled) throw new Error("expected min input re-enabled once real data is available")
      if (controller.maxTextInputTarget.disabled) throw new Error("expected max input re-enabled once real data is available")
      if (controller.minTextInputTarget.placeholder !== "Enter Min") throw new Error(`expected original placeholder restored, got ${controller.minTextInputTarget.placeholder}`)
    JS

    run_node_script("(async () => { #{script} })()")
  end

  it "re-populates the accurate 0/0 domain into cleared hidden inputs once the fetch has already settled, for a field with zero qualifying rows" do
    script = <<~JS
      const fs = require("fs")
      class Controller {}
      const FilterState = { get: () => ({ state: "OK" }) }
      global.fetch = () => Promise.resolve({
        ok: true,
        json: () => Promise.resolve({ bins: [], domain_min: 0, domain_max: 0 })
      })
      #{document_stub_js}
      global.document = documentStub
      global.CustomEvent = class {
        constructor(type) { this.type = type }
      }
      global.ResizeObserver = class {
        observe() {}
        disconnect() {}
      }

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.SliderController = class extends Controller")
      eval(source)

      const controller = new SliderController()
      controller.element = { classList: { contains: () => false }, dispatchEvent: () => {} }
      controller.fieldValue = "groundwater_rule_5yr"
      controller.urlValue = "/histogram"
      controller.formatValue = "count"
      controller.chartTarget = {
        _children: [],
        get firstChild() { return this._children[0] || null },
        removeChild(node) { this._children = this._children.filter((child) => child !== node) },
        appendChild(node) {
          node.remove = () => { this._children = this._children.filter((child) => child !== node) }
          this._children.push(node)
        },
        setAttribute() {},
        classList: { toggle() {} },
        innerHTML: "",
        getBoundingClientRect: () => ({ left: 0, width: 400 }),
        addEventListener: () => {},
        removeEventListener: () => {}
      }
      controller.minInputTarget = { value: "" }
      controller.maxInputTarget = { value: "" }
      controller.minTextInputTarget = { value: "", disabled: false, placeholder: "Enter Min" }
      controller.maxTextInputTarget = { value: "", disabled: false, placeholder: "Enter Max" }
      controller.minLabelTarget = { textContent: "" }
      controller.maxLabelTarget = { textContent: "" }
      controller.hasMinTextInputTarget = true
      controller.hasMaxTextInputTarget = true
      controller.hasZeroLabelTarget = false
      controller.connect()

      await controller.load()

      // #init's own default-population already wrote 0/0 on this first load (asserted as a
      // baseline). Clear the inputs to simulate a later re-check of an already-loaded field —
      // #loadedState is settled here, but #bins is still empty, which is exactly the ambiguity
      // populateDefaultsIfEmpty's #loadedState (not #bins.length) guard exists to resolve.
      controller.minInputTarget.value = ""
      controller.maxInputTarget.value = ""
      controller.populateDefaultsIfEmpty()

      if (String(controller.minInputTarget.value) !== "0") throw new Error(`expected hidden min input re-populated to 0, got ${controller.minInputTarget.value}`)
      if (String(controller.maxInputTarget.value) !== "0") throw new Error(`expected hidden max input re-populated to 0, got ${controller.maxInputTarget.value}`)
    JS

    run_node_script("(async () => { #{script} })()")
  end
end
