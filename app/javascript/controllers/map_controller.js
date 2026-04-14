import { Controller } from "@hotwired/stimulus"

// Manages Mapbox GL JS v3 map — M5.
// Tile source wired to /tiles/:z/:x/:y for all 5 layers.
// Hover popup on pws layer; click loads detail panel via Turbo Frame.
export default class extends Controller {
  static values = {
    tileUrl: String
  }

  connect() {
    const token = document.head.querySelector('meta[name="mapbox-token"]')?.content
    if (!token) {
      console.warn("[map] No mapbox-token meta tag found — map will not initialize")
      this.#hideLoadingMask()
      return
    }

    window.mapboxgl.accessToken = token

    this.map = new window.mapboxgl.Map({
      container: "map",
      style: "mapbox://styles/mapbox/light-v11",
      center: [-97.6, 40.27],
      zoom: 2,
      projection: "mercator"
    })

    this.map.dragRotate.disable()
    this.hoverPopup = null
    this.hoveredPwsid = null

    this.map.on("load", () => this.#onLoad())
  }

  disconnect() {
    if (this.map) {
      this.map.remove()
      this.map = null
    }
  }

  // ── Private ────────────────────────────────────────────────────────────────

  #onLoad() {
    this.#addControls()
    this.#addSource()
    this.#addLayers()
    this.#bindEvents()

    // Once the initial tiles settle, animate to working zoom and reveal the UI
    this.map.once("idle", () => {
      this.map.setZoom(3.5)
      this.#hideLoadingMask()
    })
  }

  #addControls() {
    this.map.touchZoomRotate.disableRotation()
    this.map.addControl(new window.mapboxgl.NavigationControl({ showCompass: false }), "top-left")

    if (window.MapboxGeocoder) {
      const geocoder = new window.MapboxGeocoder({
        accessToken: window.mapboxgl.accessToken,
        mapboxgl: window.mapboxgl,
        marker: false,
        flyTo: false,
        countries: "US",
        placeholder: "Search map..."
      })
      // Render geocoder into the filter bar list item rather than as a floating map control
      const geocoderLi = document.getElementById("geocoder-li")
      if (geocoderLi) {
        geocoderLi.appendChild(geocoder.onAdd(this.map))
      } else {
        this.map.addControl(geocoder, "top-left")
      }
    }
  }

  #addSource() {
    const tileUrl = `${window.location.origin}${this.tileUrlValue}`

    this.map.addSource("wdt", {
      type: "vector",
      tiles: [tileUrl]
    })
  }

  #addLayers() {
    // Insert geographic boundary fills below the first line layer in the base style
    const firstLineId = this.#firstLineLayerId()

    // ── Boundary fills (transparent — used for hover/click hit area) ──────────

    this.map.addLayer({
      id: "states",
      type: "fill",
      source: "wdt",
      "source-layer": "states",
      layout: { visibility: "visible" },
      paint: {
        "fill-color": "#fff",
        "fill-opacity": 0,
        "fill-outline-color": "#eee"
      }
    }, firstLineId)

    this.map.addLayer({
      id: "counties",
      type: "fill",
      source: "wdt",
      "source-layer": "counties",
      layout: { visibility: "visible" },
      paint: {
        "fill-color": "#fff",
        "fill-opacity": 0,
        "fill-outline-color": "#eee"
      }
    }, firstLineId)

    this.map.addLayer({
      id: "places",
      type: "fill",
      source: "wdt",
      "source-layer": "places",
      minzoom: 8,
      layout: { visibility: "visible" },
      paint: {
        "fill-color": "#fff",
        "fill-opacity": 0,
        "fill-outline-color": "#eee"
      }
    }, firstLineId)

    // ── Hover / filter highlight layers ────────────────────────────────────────

    this.map.addLayer({
      id: "states_hover",
      type: "fill",
      source: "wdt",
      "source-layer": "states",
      layout: { visibility: "visible" },
      paint: {
        "fill-color": "rgb(78, 163, 36)",
        "fill-opacity": 0.2,
        "fill-outline-color": "#999"
      },
      filter: ["in", "geoid", ""]
    })

    this.map.addLayer({
      id: "states_filter",
      type: "line",
      source: "wdt",
      "source-layer": "states",
      layout: { visibility: "visible" },
      paint: { "line-color": "#000", "line-width": 2 },
      filter: ["in", "geoid", ""]
    })

    this.map.addLayer({
      id: "counties_filter",
      type: "line",
      source: "wdt",
      "source-layer": "counties",
      layout: { visibility: "visible" },
      paint: { "line-color": "rgb(78, 163, 36)", "line-width": 2 },
      filter: ["in", "geoid", ""]
    })

    this.map.addLayer({
      id: "places_filter",
      type: "line",
      source: "wdt",
      "source-layer": "places",
      layout: { visibility: "visible" },
      paint: { "line-color": "rgb(78, 163, 36)", "line-width": 2 },
      filter: ["in", "geoid", ""]
    })

    // ── PWS service area polygons ───────────────────────────────────────────────

    this.map.addLayer({
      id: "pws",
      type: "fill",
      source: "wdt",
      "source-layer": "pws",
      layout: { visibility: "visible" },
      paint: {
        "fill-color": "rgb(78, 163, 36)",
        "fill-opacity": 0.2,
        "fill-outline-color": "#000"
      }
    }, firstLineId)

    // Thicker border on hover
    this.map.addLayer({
      id: "pws_hover",
      type: "line",
      source: "wdt",
      "source-layer": "pws",
      layout: { visibility: "visible" },
      paint: {
        "line-color": "#000",
        "line-width": { base: 2, stops: [[8, 2.5], [22, 4.5]] }
      },
      filter: ["in", "pwsid", ""]
    }, firstLineId)

    // Thin outline at higher zooms
    this.map.addLayer({
      id: "pws_outline",
      type: "line",
      source: "wdt",
      "source-layer": "pws",
      minzoom: 8,
      layout: { visibility: "visible" },
      paint: {
        "line-color": "#000",
        "line-width": { base: 1, stops: [[8, 1.5], [22, 3.5]] },
        "line-opacity": 1
      }
    })

    // Selected PWS highlight (hidden until a feature is clicked)
    this.map.addLayer({
      id: "selected_pws",
      type: "line",
      source: "wdt",
      "source-layer": "pws",
      layout: { visibility: "none" },
      paint: { "line-color": "#f00", "line-width": 2 },
      filter: ["in", "pwsid", ""]
    })

    // ── PWS centroid points (visible at lower zooms) ───────────────────────────

    this.map.addLayer({
      id: "pws_points",
      type: "circle",
      source: "wdt",
      "source-layer": "pws_points",
      maxzoom: 8,
      layout: { visibility: "visible" },
      paint: {
        "circle-color": "rgb(78, 163, 36)",
        "circle-radius": { base: 3, stops: [[2, 2], [7, 5]] },
        "circle-stroke-color": "#000",
        "circle-stroke-width": 1,
        "circle-opacity": 0.7
      }
    })
  }

  #bindEvents() {
    // ── States hover / click ──────────────────────────────────────────────────

    this.map.on("mousemove", "states", (e) => {
      const props = e.features[0].properties
      this.map.getCanvas().style.cursor = "pointer"
      this.map.setFilter("states_hover", ["in", "geoid", props.geoid])
    })

    this.map.on("mouseleave", "states", () => {
      this.map.getCanvas().style.cursor = ""
      this.map.setFilter("states_hover", ["in", "geoid", ""])
    })

    this.map.on("click", "states", (e) => {
      const props = e.features[0].properties
      this.map.setFilter("states_hover", ["in", "geoid", ""])
      this.map.setFilter("states_filter", ["in", "geoid", props.geoid])
    })

    // ── PWS polygon hover ─────────────────────────────────────────────────────

    this.map.on("mousemove", "pws", (e) => {
      if (this.map.getZoom() < 5) return

      this.map.getCanvas().style.cursor = "pointer"
      const props = e.features[0].properties

      if (props.pwsid === this.hoveredPwsid) return
      this.hoveredPwsid = props.pwsid
      this.map.setFilter("pws_hover", ["in", "pwsid", props.pwsid])

      if (this.hoverPopup) {
        this.hoverPopup.remove()
        this.hoverPopup = null
      }

      const html = this.#buildHoverHtml(props)
      this.hoverPopup = new window.mapboxgl.Popup({
        closeButton: false,
        className: "infoBub",
        maxWidth: "400px"
      })
        .setLngLat(e.lngLat)
        .setHTML(html)
        .addTo(this.map)
    })

    this.map.on("mouseleave", "pws", () => {
      if (this.map.getZoom() < 5) return

      this.map.getCanvas().style.cursor = ""
      this.hoveredPwsid = null
      this.map.setFilter("pws_hover", ["in", "pwsid", ""])

      if (this.hoverPopup) {
        this.hoverPopup.remove()
        this.hoverPopup = null
      }
    })

    this.map.on("zoomstart", () => {
      this.hoveredPwsid = null
      this.map.setFilter("pws_hover", ["in", "pwsid", ""])
      if (this.hoverPopup) {
        this.hoverPopup.remove()
        this.hoverPopup = null
      }
    })

    // ── PWS polygon click → load detail panel ────────────────────────────────

    this.map.on("click", "pws", (e) => {
      if (this.map.getZoom() < 8) {
        this.map.flyTo({ center: e.lngLat, zoom: 8.5 })
        return
      }

      const pwsid = e.features[0].properties.pwsid
      if (!pwsid) return

      // Highlight selected
      this.map.setLayoutProperty("selected_pws", "visibility", "visible")
      this.map.setFilter("selected_pws", ["in", "pwsid", pwsid])

      // Load detail panel via Turbo Frame
      const frame = document.getElementById("detail-panel")
      if (frame) {
        frame.src = `/public_water_systems/${pwsid}`
      }
    })

    // ── pws_points click (lower zooms) → zoom in ─────────────────────────────

    this.map.on("click", "pws_points", (e) => {
      this.map.flyTo({ center: e.lngLat, zoom: 8.5 })
    })

    this.map.on("mousemove", "pws_points", () => {
      this.map.getCanvas().style.cursor = "pointer"
    })

    this.map.on("mouseleave", "pws_points", () => {
      this.map.getCanvas().style.cursor = ""
    })
  }

  zoom48() {
    const input = document.querySelector(".mapboxgl-ctrl-geocoder--input")
    if (input) input.value = ""
    const closeBtn = document.querySelector(".mapboxgl-ctrl-geocoder--icon-close")
    if (closeBtn) closeBtn.click()
    this.map.flyTo({ center: [-97.6, 40.27], zoom: 3.5 })
  }

  zoomAk() {
    this.map.flyTo({ center: [-149.504, 61.342], zoom: 4.9 })
    this.map.once("idle", () => {
      this.map.flyTo({ zoom: 5, duration: 3600 })
    })
  }

  zoomHi() {
    this.map.flyTo({ center: [-157.856, 21.305], zoom: 4.9 })
    this.map.once("idle", () => {
      this.map.flyTo({ zoom: 6, duration: 3600 })
    })
  }

  #buildHoverHtml(props) {
    const pop = props.population_served_count
      ? Number(props.population_served_count).toLocaleString("en-US")
      : "—"
    const connections = props.service_connections_count
      ? Number(props.service_connections_count).toLocaleString("en-US")
      : "—"

    return `
      <div class="map-detail-header">
        <p><strong>Utility Name:</strong> ${props.pws_name || "—"}</p>
        <p><strong>System ID:</strong> ${props.pwsid || "—"}</p>
      </div>
      <div class="map-detail-body">
        <p><strong>State:</strong> ${props.stusps || "—"}</p>
        <p><strong>Service connections:</strong> ${connections}</p>
        <p><strong>Customers served:</strong> ${pop}</p>
      </div>
    `
  }

  #firstLineLayerId() {
    const layers = this.map.getStyle().layers
    for (const layer of layers) {
      if (layer.type === "line") return layer.id
    }
    return undefined
  }

  #hideLoadingMask() {
    const mask = document.getElementById("loading-mask")
    if (mask) mask.style.display = "none"
  }
}
