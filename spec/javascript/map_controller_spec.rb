require "rails_helper"
require "open3"
require "tempfile"

RSpec.describe "map_controller state selection" do
  def run_node_script(script)
    Tempfile.create(["map-controller-state-selection", ".js"]) do |file|
      file.write(script)
      file.flush

      stdout, stderr, status = Open3.capture3("node", file.path)
      expect(status).to be_success, [stdout, stderr].reject(&:empty?).join("\n")
    end
  end

  def controller_source_path
    Rails.root.join("app/javascript/controllers/map_controller.js")
  end

  it "does not crash if Mapbox re-enters while selecting a state" do
    script = <<~JS
      const fs = require("fs")
      class Controller {}
      const FilterState = {
        get: () => ({}),
        toUrlParams: () => new URLSearchParams()
      }
      global.document = {
        querySelector: () => null,
        getElementById: () => null
      }
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
      const FilterState = {
        get: () => ({}),
        toUrlParams: () => new URLSearchParams()
      }
      global.document = {
        head: { querySelector: () => ({ content: "token" }) },
        querySelector: () => null,
        getElementById: () => null,
        addEventListener: () => {},
        removeEventListener: () => {}
      }
      global.window = {
        location: { origin: "http://example.test", hostname: "example.test" },
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
      const FilterState = {
        get: () => ({}),
        toUrlParams: () => new URLSearchParams()
      }
      global.document = {
        head: { querySelector: () => ({ content: "token" }) },
        querySelector: () => null,
        getElementById: () => null,
        addEventListener: () => {},
        removeEventListener: () => {}
      }
      global.window = {
        location: { origin: "http://example.test", hostname: "example.test" },
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
      const FilterState = {
        get: () => ({}),
        toUrlParams: () => new URLSearchParams()
      }
      global.document = {
        head: { querySelector: () => ({ content: "token" }) },
        querySelector: () => null,
        getElementById: () => null,
        addEventListener: () => {},
        removeEventListener: () => {}
      }
      global.window = {
        location: { origin: "http://example.test", hostname: "example.test" },
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
end
