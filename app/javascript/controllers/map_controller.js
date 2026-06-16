import { Controller } from "@hotwired/stimulus"
import * as FilterState from "filter_state"

const DESKTOP_US_BOUNDS = [[-125.5, 23.5], [-65.5, 49.5]]
const VIEWPORT_PADDING = 20
// Gap after sidebar right edge — keep in sync with sidebar_controller.js CONTROLS_GAP
const SIDEBAR_CONTENT_GAP = 16
// Portrait mobile: fitBounds + edge padding fights the aspect ratio; use center/zoom instead.
const MOBILE_DEFAULT_CENTER = [-97.6, 38.5]
const MOBILE_DEFAULT_ZOOM = 2
const DESKTOP_MIN_ZOOM = 3
const MOBILE_MIN_ZOOM = 2

export default class extends Controller {
  static targets = ["popupTemplate"]

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

    const desktopLayout = this.#desktopMapLayout()
    const mapOptions = {
      container: "map",
      style: document.head.querySelector('meta[name="mapbox-style"]')?.content,
      minZoom: desktopLayout ? DESKTOP_MIN_ZOOM : MOBILE_MIN_ZOOM,
      projection: "mercator",
      renderWorldCopies: false
    }

    if (desktopLayout) {
      mapOptions.bounds = DESKTOP_US_BOUNDS
      mapOptions.fitBoundsOptions = { padding: this.#desktopPadding() }
    } else {
      mapOptions.center = MOBILE_DEFAULT_CENTER
      mapOptions.zoom = MOBILE_DEFAULT_ZOOM
    }

    this.map = new window.mapboxgl.Map(mapOptions)

    this.map.dragRotate.disable()
    // Dev convenience: mapDebug.getZoom(), mapDebug.getCenter(), etc. in browser console.
    if (window.location.hostname === "localhost") window.mapDebug = this.map
    this.hoverPopup = null
    this.hoveredPwsid = null
    this.activeFilterRequest = null

    this.boundOnFiltersChanged = this.#onFiltersChanged.bind(this)
    document.addEventListener("filters:changed", this.boundOnFiltersChanged)

    this.map.on("load", () => this.#onLoad())
  }

  disconnect() {
    document.removeEventListener("filters:changed", this.boundOnFiltersChanged)
    if (this.map) {
      this.map.remove()
      this.map = null
    }
  }

  // ── Private ────────────────────────────────────────────────────────────────

  // Sidebar uses hidden sm:flex — width > 0 means desktop chrome is active (no breakpoint checks).
  #desktopMapLayout() {
    const sidebar = document.getElementById("container-sidebar")
    return !!sidebar && sidebar.getBoundingClientRect().width > 0
  }

  #desktopPadding() {
    const leftInset = this.#sidebarLeftInset()
    if (!leftInset) return VIEWPORT_PADDING

    return {
      top: VIEWPORT_PADDING,
      bottom: VIEWPORT_PADDING,
      left: leftInset + VIEWPORT_PADDING,
      right: VIEWPORT_PADDING
    }
  }

  #sidebarLeftInset() {
    const mapEl = document.getElementById("map")
    const sidebar = document.getElementById("container-sidebar")
    if (!mapEl || !sidebar) return 0

    const mapRect = mapEl.getBoundingClientRect()
    const { width, right } = sidebar.getBoundingClientRect()
    if (width <= 0) return 0

    return Math.ceil(Math.max(0, right - mapRect.left)) + SIDEBAR_CONTENT_GAP
  }

  #fitDefaultView(options = {}) {
    const { duration, ...fitOptions } = options

    if (this.#desktopMapLayout()) {
      this.map.fitBounds(DESKTOP_US_BOUNDS, {
        padding: this.#desktopPadding(),
        ...fitOptions,
        ...(duration !== undefined ? { duration } : {})
      })
      return
    }

    const camera = { center: MOBILE_DEFAULT_CENTER, zoom: MOBILE_DEFAULT_ZOOM }
    if (duration === 0) {
      this.map.jumpTo(camera)
    } else {
      this.map.flyTo({ ...camera, ...(duration !== undefined ? { duration } : {}) })
    }
  }

  #onLoad() {
    this.#addControls()
    document.dispatchEvent(new CustomEvent("map:controls-added"))
    this.#addSource()
    this.#addLayers()
    this.#styleWater()
    this.#bindEvents()

    // filter_controller#restoreFromUrl dispatches filters:changed synchronously before
    // map.on("load") completes, so that event is swallowed. Re-apply here to ensure
    // URL-shared filter params are reflected in the map on initial load.
    if (Object.keys(FilterState.get()).length > 0) {
      this.#onFiltersChanged()
    }

    this.#fitDefaultView({ duration: 0 })

    this.map.once("idle", () => this.#hideLoadingMask())
  }

  #addControls() {
    this.map.touchZoomRotate.disableRotation()

    if (window.MapboxGeocoder) {
      const geocoder = new window.MapboxGeocoder({
        accessToken: window.mapboxgl.accessToken,
        mapboxgl: window.mapboxgl,
        marker: false,
        flyTo: false,
        countries: "US",
        placeholder: "Search map..."
      })

      geocoder.on("result", (ev) => {
        const placeType = ev.result.place_type?.[0]
        let zoom = 10
        if (placeType === "region") zoom = 5
        else if (placeType === "district") zoom = 7
        else if (placeType === "place") zoom = 8

        this.map.flyTo({ center: ev.result.geometry.coordinates, zoom })
      })

      // Geocoder first so it appears above the zoom controls in the top-left column
      this.map.addControl(geocoder, "top-left")
    }

    this.map.addControl(new window.mapboxgl.NavigationControl({ showCompass: false }), "top-left")
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

  }

  #styleWater() {
    // Override the base style's water color to match the legacy blue ocean look.
    // light-v11 defaults to near-white water; this restores a readable blue.
    ["water", "water-shadow"].forEach(layerId => {
      if (this.map.getLayer(layerId)) {
        this.map.setPaintProperty(layerId, "fill-color", "#a8d0e4")
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
        className: "min-w-[280px]",
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

    // ── PWS polygon click → detail popup with "View Full Report" ───────────

    this.map.on("click", "pws", (e) => {
      if (this.map.getZoom() < 8) {
        this.map.flyTo({ center: e.lngLat, zoom: 8.5 })
        return
      }

      const props = e.features[0].properties
      if (!props.pwsid) return

      // Remove hover popup so it doesn't overlap
      if (this.hoverPopup) {
        this.hoverPopup.remove()
        this.hoverPopup = null
      }

      // Highlight selected
      this.map.setLayoutProperty("selected_pws", "visibility", "visible")
      this.map.setFilter("selected_pws", ["in", "pwsid", props.pwsid])

      // Show click popup with detail + report link
      if (this.clickPopup) this.clickPopup.remove()
      this.clickPopup = new window.mapboxgl.Popup({
        closeButton: true,
        className: "min-w-[280px]",
        maxWidth: "400px"
      })
        .setLngLat(e.lngLat)
        .setHTML(this.#buildClickHtml(props))
        .addTo(this.map)

      // Wire "View Full Report" — popup DOM is outside Stimulus scope,
      // so we attach the listener manually after popup is added to the map.
      const reportLink = this.clickPopup.getElement().querySelector(".js-view-report")
      if (reportLink) {
        reportLink.addEventListener("click", (evt) => {
          if (this.#shouldFollowLink(evt)) return

          evt.preventDefault()
          const overlay = document.getElementById("container-report")
          if (overlay) overlay.classList.remove("hidden")

          if (document.querySelector("turbo-frame#report-body")) {
            Turbo.visit(reportLink.href, {frame: "report-body"})
          }

          if (this.clickPopup) this.clickPopup.remove()
        })
      }

      this.clickPopup.on("close", () => {
        this.map.setLayoutProperty("selected_pws", "visibility", "none")
        this.clickPopup = null
      })
    })

  }

  zoom48() {
    const input = document.querySelector(".mapboxgl-ctrl-geocoder--input")
    if (input) input.value = ""
    this.#fitDefaultView()
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

  zoomPr() {
    this.map.flyTo({ center: [-66.590, 18.220], zoom: 5 })
    this.map.once("idle", () => {
      this.map.flyTo({ zoom: 8, duration: 3600 })
    })
  }

  zoomGu() {
    this.map.flyTo({ center: [144.794, 13.444], zoom: 7 })
    this.map.once("idle", () => {
      this.map.flyTo({ zoom: 10, duration: 3600 })
    })
  }

  zoomMp() {
    this.map.flyTo({ center: [145.674, 15.180], zoom: 7 })
    this.map.once("idle", () => {
      this.map.flyTo({ zoom: 9, duration: 3600 })
    })
  }

  async #onFiltersChanged() {
    if (!this.map?.getLayer("pws")) return

    const filters = FilterState.get()

    if (Object.keys(filters).length === 0) {
      this.map.setFilter("pws", null)
      this.map.setFilter("pws_outline", null)
      return
    }

    // Abort any in-flight request to avoid stale results on rapid Apply
    if (this.activeFilterRequest) this.activeFilterRequest.abort()
    this.activeFilterRequest = new AbortController()

    try {
      const res = await fetch(`/map?${FilterState.toUrlParams()}`, {
        signal: this.activeFilterRequest.signal
      })
      if (!res.ok) return

      const { pwsids } = await res.json()
      if (!this.map) return

      const expr = pwsids.length > 0
        ? ["in", "pwsid", ...pwsids]
        : ["in", "pwsid", ""]

      this.map.setFilter("pws", expr)
      this.map.setFilter("pws_outline", expr)
    } catch (err) {
      if (err.name !== "AbortError") console.error("[map] filter fetch failed", err)
    }
  }

  #buildClickHtml(props) {
    return this.#buildPopupHtml(props, { showType: true, showReport: true })
  }

  #buildHoverHtml(props) {
    return this.#buildPopupHtml(props)
  }

  #buildPopupHtml(props, { showType = false, showReport = false } = {}) {
    const root = this.popupTemplateTarget.content.firstElementChild.cloneNode(true)

    root.querySelectorAll("[data-popup-field]").forEach(el => {
      const field = el.dataset.popupField
      let value = props[field]

      if (field === "population_served_count" || field === "service_connections_count") {
        value = value ? Number(value).toLocaleString("en-US") : "—"
      } else {
        value = value || "—"
      }

      el.textContent = value
    })

    if (showType) {
      root.querySelector('[data-popup-section="type"]')?.classList.remove("hidden")
    }

    if (showReport) {
      root.querySelector('[data-popup-section="report"]')?.classList.remove("hidden")
      const link = root.querySelector(".js-view-report")
      if (link && props.pwsid) link.href = this.#reportPath(props.pwsid)
    }

    return root.outerHTML
  }

  #reportPath(pwsid) {
    return `/public_water_systems/${encodeURIComponent(pwsid)}/report`
  }

  #shouldFollowLink(evt) {
    return evt.button !== 0 || evt.metaKey || evt.ctrlKey || evt.shiftKey || evt.altKey
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
    if (mask) mask.classList.add("hidden")
  }
}
