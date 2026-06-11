require "rails_helper"
require "open3"
require "tempfile"

RSpec.describe "map_controller state selection" do
  def run_node_script(script)
    Tempfile.create(["map-controller-state-selection", ".js"]) do |file|
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
      JS
      file.write(script)
      file.flush

      stdout, stderr, status = Open3.capture3("node", file.path)
      expect(status).to be_success, [stdout, stderr].reject(&:empty?).join("\n")
    end
  end

  def controller_source_path
    Rails.root.join("app/javascript/controllers/map_controller.js")
  end

  it "writes clicked state params to FilterState, updates the URL, and dispatches filters:changed" do
    script = <<~JS
      const fs = require("fs")
      class Controller {}
      const filterStateCurrent = {}
      const FilterState = {
        get: () => ({ ...filterStateCurrent }),
        set: (params) => {
          Object.keys(filterStateCurrent).forEach((key) => delete filterStateCurrent[key])
          Object.assign(filterStateCurrent, params)
        },
        toUrlParams: () => new URLSearchParams(filterStateCurrent)
      }
      const dispatchedEvents = []
      const replacedUrls = []
      global.document = {
        head: { querySelector: () => ({ content: "token" }) },
        querySelector: () => null,
        getElementById: () => null,
        addEventListener: () => {},
        removeEventListener: () => {},
        dispatchEvent: (event) => dispatchedEvents.push(event.type)
      }
      global.CustomEvent = class {
        constructor(type) { this.type = type }
      }
      global.history = { replaceState: (_state, _title, url) => replacedUrls.push(String(url)) }
      global.window = {
        location: new URL("http://example.test/"),
        mapboxgl: {}
      }
      global.Turbo = { visit: () => {} }

      class MapStub {
        constructor() {
          this.handlers = {}
          this.zoom = 3
          globalThis.mapStub = this
        }

        dragRotate = { disable: () => {} }
        touchZoomRotate = { disableRotation: () => {} }
        getStyle() { return { layers: [{ id: "base-line", type: "line" }] } }
        getCanvas() { return { style: {} } }
        getZoom() { return this.zoom }
        addControl() {}
        addSource() {}
        addLayer() {}
        setPaintProperty() {}
        getLayer() { return true }
        setFilter() {}
        setMaxZoom() {}
        fitBounds() {}
        jumpTo(options) { if (options.zoom !== undefined) this.zoom = options.zoom }
        flyTo(options) { if (options.zoom !== undefined) this.zoom = options.zoom }
        once() {}
        on(event, layerOrCallback, callback) {
          if (callback) {
            this.handlers[`${event}:${layerOrCallback}`] = callback
          } else {
            this.handlers[event] = layerOrCallback
          }
        }
      }

      window.mapboxgl.Map = MapStub
      window.mapboxgl.NavigationControl = class {}

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.MapController = class extends Controller")
      eval(source)

      const controller = new MapController()
      controller.element = { dataset: {} }
      controller.tileUrlValue = "/tiles/{z}/{x}/{y}.mvt"
      controller.connect()
      mapStub.handlers.load()

      mapStub.handlers["click:states"]({
        lngLat: { lng: -105.5, lat: 39.0 },
        features: [{ properties: { stusps: "CO", name: "Colorado", geoid: "08" } }]
      })

      if (filterStateCurrent.state !== "CO") throw new Error(`expected state CO, got ${filterStateCurrent.state}`)
      if (filterStateCurrent.state_name !== "Colorado") throw new Error(`expected state_name Colorado, got ${filterStateCurrent.state_name}`)
      if (!dispatchedEvents.includes("filters:changed")) throw new Error("expected filters:changed to be dispatched")
      if (!replacedUrls.at(-1)?.includes("state=CO")) throw new Error(`expected URL to include state=CO, got ${replacedUrls.at(-1)}`)
      if (!replacedUrls.at(-1)?.includes("state_name=Colorado")) throw new Error(`expected URL to include state_name=Colorado, got ${replacedUrls.at(-1)}`)
    JS

    run_node_script(script)
  end

  it "does not fetch map ids for a state-only filter change but does fetch for additional filters without state params" do
    script = <<~JS
      const fs = require("fs")
      class Controller {}
      let currentFilters = { state: "CO", state_name: "Colorado" }
      const FilterState = {
        get: () => ({ ...currentFilters }),
        toUrlParams: () => new URLSearchParams(currentFilters)
      }
      const fetchUrls = []
      global.fetch = async (url) => {
        fetchUrls.push(url)
        return { ok: true, json: async () => ({ pwsids: ["CO0000001"] }) }
      }
      global.document = {
        querySelector: () => null,
        getElementById: () => null
      }
      global.Turbo = { visit: () => {} }
      global.AbortController = class {
        constructor() { this.signal = {} }
        abort() {}
      }

      ;(async () => {
        let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
        source = source.replace(/^import .*\\n/gm, "")
        source = source.replaceAll("#onFiltersChanged", "onFiltersChanged")
        source = source.replace("export default class extends Controller", "globalThis.MapController = class extends Controller")
        eval(source)

        const controller = new MapController()
        controller.element = { dataset: { selectedState: "CO", selectedStateName: "Colorado" } }
        controller.selectedState = { stusps: "CO", name: "Colorado", geoid: "08" }
        controller.filteredPwsids = null
        controller.hoverPopup = null
        controller.clickPopup = null
        controller.stateHoverPopup = null
        controller.activeFilterRequest = null
        controller.mapMode = "state"
        controller.map = {
          getLayer: () => true,
          setFilter: () => {}
        }

        await controller.onFiltersChanged()
        if (fetchUrls.length !== 0) throw new Error(`expected no state-only /map fetch, got ${fetchUrls.join(", ")}`)

        currentFilters = { state: "CO", state_name: "Colorado", gw_sw_code: "Groundwater" }
        await controller.onFiltersChanged()
        if (fetchUrls.length !== 1) throw new Error(`expected one /map fetch, got ${fetchUrls.length}`)
        if (fetchUrls[0] !== "/map?gw_sw_code=Groundwater") throw new Error(`expected state params removed from /map fetch, got ${fetchUrls[0]}`)
      })()
    JS

    run_node_script(script)
  end

  it "aborts stale map id requests when filters change back to state-only" do
    script = <<~JS
      const fs = require("fs")
      class Controller {}
      let currentFilters = { state: "CO", state_name: "Colorado", gw_sw_code: "Groundwater" }
      const FilterState = {
        get: () => ({ ...currentFilters }),
        toUrlParams: () => new URLSearchParams(currentFilters)
      }
      let abortCalled = false
      const pendingFetches = []
      global.fetch = (url, options) => {
        pendingFetches.push({ url, options })
        return new Promise((resolve) => {
          pendingFetches.at(-1).resolve = resolve
        })
      }
      global.document = {
        querySelector: () => null,
        getElementById: () => null
      }
      global.Turbo = { visit: () => {} }
      global.AbortController = class {
        constructor() { this.signal = {} }
        abort() { abortCalled = true }
      }

      ;(async () => {
        let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
        source = source.replace(/^import .*\\n/gm, "")
        source = source.replaceAll("#onFiltersChanged", "onFiltersChanged")
        source = source.replace("export default class extends Controller", "globalThis.MapController = class extends Controller")
        eval(source)

        const appliedFilters = []
        const controller = new MapController()
        controller.element = { dataset: { selectedState: "CO", selectedStateName: "Colorado" } }
        controller.selectedState = { stusps: "CO", name: "Colorado", geoid: "08" }
        controller.filteredPwsids = null
        controller.hoverPopup = null
        controller.clickPopup = null
        controller.stateHoverPopup = null
        controller.activeFilterRequest = null
        controller.mapMode = "state"
        controller.map = {
          getLayer: () => true,
          setFilter: (layer, filter) => {
            if (layer === "pws") appliedFilters.push(filter)
          }
        }

        const firstChange = controller.onFiltersChanged()
        if (pendingFetches.length !== 1) throw new Error(`expected one pending /map fetch, got ${pendingFetches.length}`)

        currentFilters = { state: "CO", state_name: "Colorado" }
        await controller.onFiltersChanged()
        if (!abortCalled) throw new Error("expected state-only change to abort the pending /map request")

        pendingFetches[0].resolve({ ok: true, json: async () => ({ pwsids: ["CO0000001"] }) })
        await firstChange

        const finalFilter = JSON.stringify(appliedFilters.at(-1))
        const expectedFilter = JSON.stringify(["==", "stusps", "CO"])
        if (finalFilter !== expectedFilter) throw new Error(`expected stale response not to re-filter pws, got ${finalFilter}`)
      })()
    JS

    run_node_script(script)
  end

  it "restores a selected state from FilterState during map load" do
    script = <<~JS
      const fs = require("fs")
      class Controller {}
      const filterStateCurrent = { state: "CO", state_name: "Colorado" }
      const FilterState = {
        get: () => ({ ...filterStateCurrent }),
        set: (params) => {
          Object.keys(filterStateCurrent).forEach((key) => delete filterStateCurrent[key])
          Object.assign(filterStateCurrent, params)
        },
        toUrlParams: () => new URLSearchParams(filterStateCurrent)
      }
      const dispatchedEvents = []
      global.document = {
        head: { querySelector: () => ({ content: "token" }) },
        querySelector: () => null,
        getElementById: () => null,
        addEventListener: () => {},
        removeEventListener: () => {},
        dispatchEvent: (event) => dispatchedEvents.push(event.type)
      }
      global.CustomEvent = class {
        constructor(type) { this.type = type }
      }
      global.history = { replaceState: () => {} }
      global.window = {
        location: new URL("http://example.test/?state=CO&state_name=Colorado"),
        mapboxgl: {}
      }
      global.Turbo = { visit: () => {} }

      class MapStub {
        constructor() {
          this.handlers = {}
          this.zoom = 3
          this.filters = {}
          globalThis.mapStub = this
        }

        dragRotate = { disable: () => {} }
        touchZoomRotate = { disableRotation: () => {} }
        getStyle() { return { layers: [{ id: "base-line", type: "line" }] } }
        getCanvas() { return { style: {} } }
        getZoom() { return this.zoom }
        addControl() {}
        addSource() {}
        addLayer() {}
        setPaintProperty() {}
        getLayer() { return true }
        setFilter(layer, filter) { this.filters[layer] = filter }
        setMaxZoom(value) { this.maxZoom = value }
        fitBounds() {}
        jumpTo(options) { if (options.zoom !== undefined) this.zoom = options.zoom }
        flyTo(options) { if (options.zoom !== undefined) this.zoom = options.zoom }
        once() {}
        on(event, layerOrCallback, callback) {
          if (callback) {
            this.handlers[`${event}:${layerOrCallback}`] = callback
          } else {
            this.handlers[event] = layerOrCallback
          }
        }
      }

      window.mapboxgl.Map = MapStub
      window.mapboxgl.NavigationControl = class {}

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.MapController = class extends Controller")
      eval(source)

      const controller = new MapController()
      controller.element = { dataset: {} }
      controller.tileUrlValue = "/tiles/{z}/{x}/{y}.mvt"
      controller.connect()
      mapStub.handlers.load()

      if (controller.element.dataset.selectedState !== "CO") throw new Error(`expected selectedState CO, got ${controller.element.dataset.selectedState}`)
      if (controller.element.dataset.selectedStateName !== "Colorado") throw new Error(`expected selectedStateName Colorado, got ${controller.element.dataset.selectedStateName}`)
      const expectedPwsFilter = JSON.stringify(["==", "stusps", "CO"])
      const actualPwsFilter = JSON.stringify(mapStub.filters.pws)
      if (actualPwsFilter !== expectedPwsFilter) throw new Error(`expected pws filter ${expectedPwsFilter}, got ${actualPwsFilter}`)
      const expectedStateFilter = JSON.stringify(["==", ["get", "stusps"], "CO"])
      const actualStateFilter = JSON.stringify(mapStub.filters.states_filter)
      if (actualStateFilter !== expectedStateFilter) throw new Error(`expected states_filter ${expectedStateFilter}, got ${actualStateFilter}`)
      if (dispatchedEvents.includes("filters:changed")) throw new Error("expected load restore not to redispatch filters:changed")
    JS

    run_node_script(script)
  end

  it "removes selected state params on zoom48 and dispatches filters:changed" do
    script = <<~JS
      const fs = require("fs")
      class Controller {}
      const filterStateCurrent = { state: "CO", state_name: "Colorado", gw_sw_code: "Groundwater" }
      const FilterState = {
        get: () => ({ ...filterStateCurrent }),
        set: (params) => {
          Object.keys(filterStateCurrent).forEach((key) => delete filterStateCurrent[key])
          Object.assign(filterStateCurrent, params)
        },
        toUrlParams: () => new URLSearchParams(filterStateCurrent)
      }
      const dispatchedEvents = []
      const replacedUrls = []
      global.document = {
        querySelector: () => null,
        getElementById: (id) => {
          if (id === "container-sidebar" || id === "map") return null
          return { classList: { remove: () => {}, add: () => {} } }
        },
        dispatchEvent: (event) => dispatchedEvents.push(event.type)
      }
      global.CustomEvent = class {
        constructor(type) { this.type = type }
      }
      global.history = { replaceState: (_state, _title, url) => replacedUrls.push(String(url)) }
      global.window = { location: new URL("http://example.test/?state=CO&state_name=Colorado&gw_sw_code=Groundwater") }
      global.Turbo = { visit: () => {} }

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.MapController = class extends Controller")
      eval(source)

      const controller = new MapController()
      controller.element = { dataset: { selectedState: "CO", selectedStateName: "Colorado" } }
      controller.selectedState = { stusps: "CO", name: "Colorado", geoid: "08" }
      controller.filteredPwsids = null
      controller.hoverPopup = null
      controller.clickPopup = null
      controller.stateHoverPopup = null
      controller.map = {
        setMaxZoom: () => {},
        setFilter: () => {},
        getLayer: () => true,
        fitBounds: () => {},
        flyTo: () => {}
      }

      controller.zoom48()

      if (filterStateCurrent.state != null) throw new Error("expected zoom48 to remove state")
      if (filterStateCurrent.state_name != null) throw new Error("expected zoom48 to remove state_name")
      if (filterStateCurrent.gw_sw_code !== "Groundwater") throw new Error("expected zoom48 to preserve normal filters")
      if (!dispatchedEvents.includes("filters:changed")) throw new Error("expected filters:changed to be dispatched")
      const url = replacedUrls.at(-1)
      if (!url) throw new Error("expected URL replacement")
      if (url.includes("state=") || url.includes("state_name=")) throw new Error(`expected URL to remove state params, got ${url}`)
      if (!url.includes("gw_sw_code=Groundwater")) throw new Error(`expected URL to preserve normal filters, got ${url}`)
    JS

    run_node_script(script)
  end

  it "does not crash if Mapbox re-enters while selecting a state" do
    script = <<~JS
      const fs = require("fs")
      class Controller {}
      const filterStateCurrent = {}
      const FilterState = {
        get: () => ({ ...filterStateCurrent }),
        set: (params) => {
          Object.keys(filterStateCurrent).forEach((key) => delete filterStateCurrent[key])
          Object.assign(filterStateCurrent, params)
        },
        toUrlParams: () => new URLSearchParams(filterStateCurrent)
      }
      global.document = {
        querySelector: () => null,
        getElementById: () => null,
        dispatchEvent: () => {}
      }
      global.CustomEvent = class {
        constructor(type) { this.type = type }
      }
      global.history = { replaceState: () => {} }
      global.window = { location: new URL("http://example.test/") }
      global.Turbo = { visit: () => {} }

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.MapController = class extends Controller")
      eval(source)

      const controller = new MapController()
      let flyToCalled = false
      controller.element = { dataset: {} }
      controller.hoverPopup = null
      controller.clickPopup = null
      controller.filteredPwsids = null
      controller.stateHoverPopup = null
      controller.selectedState = null
      controller.map = {
        getZoom: () => 3,
        getLayer: () => true,
        setFilter: () => {},
        setMaxZoom: () => { controller.selectedState = null },
        flyTo: () => { flyToCalled = true },
        once: (_event, callback) => callback()
      }

      controller.zoomAk()
      if (!flyToCalled) throw new Error("expected zoomAk to continue after state selection")
    JS

    run_node_script(script)
  end

  it "zooms state clicks from nation mode to the state selection level" do
    script = <<~JS
      const fs = require("fs")
      class Controller {}
      const filterStateCurrent = {}
      const FilterState = {
        get: () => ({ ...filterStateCurrent }),
        set: (params) => {
          Object.keys(filterStateCurrent).forEach((key) => delete filterStateCurrent[key])
          Object.assign(filterStateCurrent, params)
        },
        toUrlParams: () => new URLSearchParams(filterStateCurrent)
      }
      global.document = {
        head: { querySelector: () => ({ content: "token" }) },
        querySelector: () => null,
        getElementById: () => null,
        addEventListener: () => {},
        removeEventListener: () => {},
        dispatchEvent: () => {}
      }
      global.CustomEvent = class {
        constructor(type) { this.type = type }
      }
      global.history = { replaceState: () => {} }
      global.window = {
        location: new URL("http://example.test/"),
        mapboxgl: {}
      }
      global.Turbo = { visit: () => {} }

      class MapStub {
        constructor() {
          this.handlers = {}
          this.zoom = 3
          this.flyToCalls = []
          globalThis.mapStub = this
        }

        dragRotate = { disable: () => {} }
        touchZoomRotate = { disableRotation: () => {} }
        getStyle() { return { layers: [{ id: "base-line", type: "line" }] } }
        getCanvas() { return { style: {} } }
        getZoom() { return this.zoom }
        addControl() {}
        addSource() {}
        addLayer() {}
        setPaintProperty() {}
        getLayer() { return true }
        setFilter() {}
        setMaxZoom() {}
        fitBounds() {}
        jumpTo(options) {
          if (options.zoom !== undefined) this.zoom = options.zoom
        }
        flyTo(options) {
          this.flyToCalls.push(options)
          if (options.zoom !== undefined) this.zoom = options.zoom
        }
        once() {}
        on(event, layerOrCallback, callback) {
          if (callback) {
            this.handlers[`${event}:${layerOrCallback}`] = callback
          } else {
            this.handlers[event] = layerOrCallback
          }
        }
      }

      window.mapboxgl.Map = MapStub
      window.mapboxgl.NavigationControl = class {}

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.MapController = class extends Controller")
      eval(source)

      const controller = new MapController()
      controller.element = { dataset: {} }
      controller.tileUrlValue = "/tiles/{z}/{x}/{y}.mvt"
      controller.connect()
      mapStub.handlers.load()
      mapStub.flyToCalls = []

      mapStub.handlers["click:states"]({
        lngLat: { lng: -105.5, lat: 39.0 },
        features: [{ properties: { stusps: "CO", name: "Colorado", geoid: "08" } }]
      })

      const clickFlyTo = mapStub.flyToCalls.at(-1)
      if (!clickFlyTo) throw new Error("expected state click to fly")
      if (clickFlyTo.zoom !== 6) throw new Error(`expected state click zoom 6, got ${clickFlyTo.zoom}`)
    JS

    run_node_script(script)
  end

  it "reveals selected-state service areas at the state selection level" do
    script = <<~JS
      const fs = require("fs")
      class Controller {}
      const filterStateCurrent = {}
      const FilterState = {
        get: () => ({ ...filterStateCurrent }),
        set: (params) => {
          Object.keys(filterStateCurrent).forEach((key) => delete filterStateCurrent[key])
          Object.assign(filterStateCurrent, params)
        },
        toUrlParams: () => new URLSearchParams(filterStateCurrent)
      }
      global.document = {
        head: { querySelector: () => ({ content: "token" }) },
        querySelector: () => null,
        getElementById: () => null,
        addEventListener: () => {},
        removeEventListener: () => {},
        dispatchEvent: () => {}
      }
      global.CustomEvent = class {
        constructor(type) { this.type = type }
      }
      global.history = { replaceState: () => {} }
      global.window = {
        location: new URL("http://example.test/"),
        mapboxgl: {}
      }
      global.Turbo = { visit: () => {} }

      class MapStub {
        constructor() {
          this.handlers = {}
          this.zoom = 3
          this.layers = []
          this.filters = {}
          globalThis.mapStub = this
        }

        dragRotate = { disable: () => {} }
        touchZoomRotate = { disableRotation: () => {} }
        getStyle() { return { layers: [{ id: "base-line", type: "line" }] } }
        getCanvas() { return { style: {} } }
        getZoom() { return this.zoom }
        addControl() {}
        addSource() {}
        addLayer(layer) { this.layers.push(layer) }
        setPaintProperty() {}
        getLayer() { return true }
        setFilter(layer, filter) { this.filters[layer] = filter }
        setMaxZoom() {}
        fitBounds() {}
        jumpTo(options) {
          if (options.zoom !== undefined) this.zoom = options.zoom
        }
        flyTo(options) {
          if (options.zoom !== undefined) this.zoom = options.zoom - 0.01
        }
        once() {}
        on(event, layerOrCallback, callback) {
          if (callback) {
            this.handlers[`${event}:${layerOrCallback}`] = callback
          } else {
            this.handlers[event] = layerOrCallback
          }
        }
      }

      window.mapboxgl.Map = MapStub
      window.mapboxgl.NavigationControl = class {}

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.MapController = class extends Controller")
      eval(source)

      const controller = new MapController()
      controller.element = { dataset: {} }
      controller.tileUrlValue = "/tiles/{z}/{x}/{y}.mvt"
      controller.connect()
      mapStub.handlers.load()

      mapStub.handlers["click:states"]({
        lngLat: { lng: -105.5, lat: 39.0 },
        features: [{ properties: { stusps: "CO", name: "Colorado", geoid: "08" } }]
      })

      const pwsLayer = mapStub.layers.find((layer) => layer.id === "pws")
      if (!pwsLayer) throw new Error("expected pws layer to be registered")
      if ((pwsLayer.minzoom ?? 0) > mapStub.zoom) {
        throw new Error(`expected pws to be visible at zoom ${mapStub.zoom}, got minzoom ${pwsLayer.minzoom}`)
      }

      const expectedFilter = JSON.stringify(["==", "stusps", "CO"])
      const actualFilter = JSON.stringify(mapStub.filters.pws)
      if (actualFilter !== expectedFilter) {
        throw new Error(`expected pws filter ${expectedFilter}, got ${actualFilter}`)
      }
    JS

    run_node_script(script)
  end

  it "does not let state hover compete with systems once service areas are active" do
    script = <<~JS
      const fs = require("fs")
      class Controller {}
      const filterStateCurrent = {}
      const FilterState = {
        get: () => ({ ...filterStateCurrent }),
        set: (params) => {
          Object.keys(filterStateCurrent).forEach((key) => delete filterStateCurrent[key])
          Object.assign(filterStateCurrent, params)
        },
        toUrlParams: () => new URLSearchParams(filterStateCurrent)
      }
      global.document = {
        head: { querySelector: () => ({ content: "token" }) },
        querySelector: () => null,
        getElementById: () => null,
        addEventListener: () => {},
        removeEventListener: () => {},
        dispatchEvent: () => {}
      }
      global.CustomEvent = class {
        constructor(type) { this.type = type }
      }
      global.history = { replaceState: () => {} }
      global.window = {
        location: new URL("http://example.test/"),
        mapboxgl: {}
      }
      global.Turbo = { visit: () => {} }

      class MapStub {
        constructor() {
          this.handlers = {}
          this.zoom = 8.5
          this.canvas = { style: {} }
          this.filters = []
          globalThis.mapStub = this
        }

        dragRotate = { disable: () => {} }
        touchZoomRotate = { disableRotation: () => {} }
        getStyle() { return { layers: [{ id: "base-line", type: "line" }] } }
        getCanvas() { return this.canvas }
        getZoom() { return this.zoom }
        addControl() {}
        addSource() {}
        addLayer() {}
        setPaintProperty() {}
        getLayer() { return true }
        setFilter(layer, filter) { this.filters.push([layer, filter]) }
        setMaxZoom() {}
        fitBounds() {}
        jumpTo(options) { if (options.zoom !== undefined) this.zoom = options.zoom }
        flyTo(options) { if (options.zoom !== undefined) this.zoom = options.zoom }
        once() {}
        on(event, layerOrCallback, callback) {
          if (callback) {
            this.handlers[`${event}:${layerOrCallback}`] = callback
          } else {
            this.handlers[event] = layerOrCallback
          }
        }
      }

      window.mapboxgl.Map = MapStub
      window.mapboxgl.NavigationControl = class {}

      let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
      source = source.replace(/^import .*\\n/gm, "")
      source = source.replace("export default class extends Controller", "globalThis.MapController = class extends Controller")
      eval(source)

      const controller = new MapController()
      controller.element = { dataset: {} }
      controller.tileUrlValue = "/tiles/{z}/{x}/{y}.mvt"
      controller.connect()
      mapStub.handlers.load()
      mapStub.handlers["click:states"]({
        lngLat: { lng: -105.5, lat: 39.0 },
        features: [{ properties: { stusps: "CO", name: "Colorado", geoid: "08" } }]
      })
      mapStub.zoom = 8.5
      mapStub.handlers.zoomend()

      mapStub.filters = []
      mapStub.handlers["mousemove:states"]({
        lngLat: { lng: -105.5, lat: 39.0 },
        features: [{ properties: { stusps: "CO", name: "Colorado", geoid: "08" } }]
      })

      const stateHoverUpdates = mapStub.filters.filter(([layer]) => layer === "states_hover")
      if (stateHoverUpdates.length > 0) throw new Error("expected systems mode to ignore state hover")
      if (mapStub.canvas.style.cursor === "pointer") throw new Error("expected state hover not to own the cursor in systems mode")
    JS

    run_node_script(script)
  end

  it "ignores stale geocoder state lookups when search results resolve out of order" do
    script = <<~JS
      const fs = require("fs")
      class Controller {}
      const filterStateCurrent = {}
      const FilterState = {
        get: () => ({ ...filterStateCurrent }),
        set: (params) => {
          Object.keys(filterStateCurrent).forEach((key) => delete filterStateCurrent[key])
          Object.assign(filterStateCurrent, params)
        },
        toUrlParams: () => new URLSearchParams(filterStateCurrent)
      }
      const lookups = []
      global.fetch = (url) => new Promise((resolve) => {
        lookups.push({ url, resolve })
      })
      global.document = {
        head: { querySelector: () => ({ content: "token" }) },
        querySelector: () => null,
        getElementById: () => null,
        addEventListener: () => {},
        removeEventListener: () => {},
        dispatchEvent: () => {}
      }
      global.CustomEvent = class {
        constructor(type) { this.type = type }
      }
      global.history = { replaceState: () => {} }
      global.window = {
        location: new URL("http://example.test/"),
        mapboxgl: {}
      }
      global.Turbo = { visit: () => {} }

      class GeocoderStub {
        constructor() { globalThis.geocoderStub = this; this.handlers = {} }
        on(event, callback) { this.handlers[event] = callback }
      }

      class MapStub {
        constructor() {
          this.handlers = {}
          this.zoom = 3
          this.flyToCalls = []
          globalThis.mapStub = this
        }

        dragRotate = { disable: () => {} }
        touchZoomRotate = { disableRotation: () => {} }
        getStyle() { return { layers: [{ id: "base-line", type: "line" }] } }
        getCanvas() { return { style: {} } }
        getZoom() { return this.zoom }
        addControl() {}
        addSource() {}
        addLayer() {}
        setPaintProperty() {}
        getLayer() { return true }
        setFilter() {}
        setMaxZoom() {}
        fitBounds() {}
        jumpTo(options) { if (options.zoom !== undefined) this.zoom = options.zoom }
        flyTo(options) {
          this.flyToCalls.push(options)
          if (options.zoom !== undefined) this.zoom = options.zoom
        }
        once() {}
        on(event, layerOrCallback, callback) {
          if (callback) {
            this.handlers[`${event}:${layerOrCallback}`] = callback
          } else {
            this.handlers[event] = layerOrCallback
          }
        }
      }

      ;(async () => {
        window.mapboxgl.Map = MapStub
        window.mapboxgl.NavigationControl = class {}
        window.MapboxGeocoder = GeocoderStub

        let source = fs.readFileSync(#{controller_source_path.to_s.inspect}, "utf8")
        source = source.replace(/^import .*\\n/gm, "")
        source = source.replace("export default class extends Controller", "globalThis.MapController = class extends Controller")
        eval(source)

        const controller = new MapController()
        controller.element = { dataset: {} }
        controller.tileUrlValue = "/tiles/{z}/{x}/{y}.mvt"
        controller.connect()
        mapStub.handlers.load()

        const first = geocoderStub.handlers.result({
          result: { place_type: ["place"], geometry: { coordinates: [-105, 39] } }
        })
        const second = geocoderStub.handlers.result({
          result: { place_type: ["place"], geometry: { coordinates: [-122, 47] } }
        })

        if (lookups.length !== 2) throw new Error(`expected two lookups, got ${lookups.length}`)

        lookups[1].resolve({ ok: true, json: async () => ({ stusps: "WA", name: "Washington", geoid: "53" }) })
        await second
        lookups[0].resolve({ ok: true, json: async () => ({ stusps: "CO", name: "Colorado", geoid: "08" }) })
        await first

        if (filterStateCurrent.state !== "WA") throw new Error(`expected latest geocoder state WA, got ${filterStateCurrent.state}`)
        const lastFlyTo = mapStub.flyToCalls.at(-1)
        if (JSON.stringify(lastFlyTo.center) !== JSON.stringify([-122, 47])) {
          throw new Error(`expected latest geocoder center to win, got ${JSON.stringify(lastFlyTo.center)}`)
        }
      })()
    JS

    run_node_script(script)
  end
end
