import { Controller } from "@hotwired/stimulus"
import * as FilterState from "filter_state"
import { syncStatsFrame } from "stats_frame"
import { syncToUrl } from "url_sync"

const DESKTOP_US_BOUNDS = [[-125.5, 23.5], [-65.5, 49.5]]
const VIEWPORT_PADDING = 20
// Gap after sidebar right edge — keep in sync with sidebar_controller.js CONTROLS_GAP
const SIDEBAR_CONTENT_GAP = 16
// Portrait mobile: fitBounds + edge padding fights the aspect ratio; use center/zoom instead.
const MOBILE_DEFAULT_CENTER = [-97.6, 38.5]
const MOBILE_DEFAULT_ZOOM = 2
const DESKTOP_MIN_ZOOM = 3
const MOBILE_MIN_ZOOM = 2
const NATION_MAX_ZOOM = 4.75
const SERVICE_AREAS_MIN_ZOOM = MOBILE_MIN_ZOOM
const STATE_ENTRY_ZOOM = 6
const STATE_EXIT_ZOOM = 4.55
const SYSTEMS_ENTRY_ZOOM = 8
const UNLOCKED_MAX_ZOOM = 22
const MODE_NATION = "nation"
const MODE_STATE = "state"
const MODE_SYSTEMS = "systems"
const EMPTY_PWS_FILTER = ["in", "pwsid", ""]
const EMPTY_STATE_FILTER = ["==", ["get", "geoid"], ""]
const HOVER_STATE_EXPR = ["boolean", ["feature-state", "hover"], false]
const REGION_STATES = {
  AK: { stusps: "AK", name: "Alaska", geoid: "02" },
  HI: { stusps: "HI", name: "Hawaii", geoid: "15" },
  PR: { stusps: "PR", name: "Puerto Rico", geoid: "72" },
  GU: { stusps: "GU", name: "Guam", geoid: "66" },
  MP: { stusps: "MP", name: "Northern Mariana Islands", geoid: "69" }
}
// PostGIS-derived bounding boxes for state zoom-to-fit. Static because state borders never change,
// an API call adds latency, and querySourceFeatures only covers tiles already in the viewport.
const STATE_FIT_BOUNDS = {
  AL: [[-88.47, 30.22], [-84.89, 35.01]],
  AR: [[-94.62, 33.0],  [-89.64, 36.5]],
  AS: [[-171.09, -14.55], [-168.14, -11.05]],
  AZ: [[-114.82, 31.33], [-109.05, 37.0]],
  CA: [[-124.41, 32.53], [-114.13, 42.01]],
  CO: [[-109.06, 36.99], [-102.04, 41.0]],
  CT: [[-73.73, 40.98], [-71.79, 42.05]],
  DC: [[-77.12, 38.79], [-76.91, 39.0]],
  DE: [[-75.79, 38.45], [-75.05, 39.84]],
  FL: [[-87.63, 24.52], [-80.03, 31.0]],
  GA: [[-85.61, 30.36], [-80.84, 35.0]],
  GU: [[144.62, 13.23],  [144.96, 13.65]],
  HI: [[-160.5, 18.5],  [-154.5, 22.3]],
  IA: [[-96.64, 40.38], [-90.14, 43.5]],
  ID: [[-117.24, 41.99], [-111.04, 49.0]],
  IL: [[-91.51, 36.97], [-87.5, 42.51]],
  IN: [[-88.1, 37.77],  [-84.78, 41.76]],
  KS: [[-102.05, 36.99], [-94.59, 40.0]],
  KY: [[-89.57, 36.5],  [-81.96, 39.15]],
  LA: [[-94.04, 28.93], [-88.82, 33.02]],
  MA: [[-73.51, 41.24], [-69.93, 42.89]],
  MD: [[-79.49, 37.91], [-75.05, 39.72]],
  ME: [[-71.08, 42.98], [-66.95, 47.46]],
  MI: [[-90.42, 41.7],  [-82.41, 48.24]],
  MN: [[-97.24, 43.5],  [-89.49, 49.38]],
  MO: [[-95.77, 36.0],  [-89.1, 40.61]],
  MP: [[144.89, 14.11], [146.06, 20.55]],
  MS: [[-91.66, 30.18], [-88.1, 35.0]],
  MT: [[-116.05, 44.36], [-104.04, 49.0]],
  NC: [[-84.32, 33.84], [-75.46, 36.59]],
  ND: [[-104.05, 45.94], [-96.55, 49.0]],
  NE: [[-104.05, 40.0], [-95.31, 43.0]],
  NH: [[-72.56, 42.7],  [-70.61, 45.31]],
  NJ: [[-75.56, 38.93], [-73.89, 41.36]],
  NM: [[-109.05, 31.33], [-103.0, 37.0]],
  NV: [[-120.01, 35.0], [-114.04, 42.0]],
  NY: [[-79.76, 40.5],  [-71.86, 45.02]],
  OH: [[-84.82, 38.4],  [-80.52, 41.98]],
  OK: [[-103.0, 33.62], [-94.43, 37.0]],
  OR: [[-124.57, 41.99], [-116.46, 46.29]],
  PA: [[-80.52, 39.72], [-74.69, 42.27]],
  PR: [[-67.95, 17.88], [-65.22, 18.52]],
  RI: [[-71.86, 41.15], [-71.12, 42.02]],
  SC: [[-83.35, 32.04], [-78.55, 35.22]],
  SD: [[-104.06, 42.48], [-96.44, 45.95]],
  TN: [[-90.31, 34.98], [-81.65, 36.68]],
  TX: [[-106.65, 25.84], [-93.51, 36.5]],
  UT: [[-114.05, 37.0], [-109.04, 42.0]],
  VA: [[-83.68, 36.54], [-75.24, 39.47]],
  VI: [[-65.09, 17.67], [-64.57, 18.42]],
  VT: [[-73.44, 42.73], [-71.46, 45.02]],
  WA: [[-124.76, 45.54], [-116.92, 49.0]],
  WI: [[-92.89, 42.49], [-86.81, 47.08]],
  WV: [[-82.64, 37.2],  [-77.72, 40.64]],
  WY: [[-111.05, 40.99], [-104.05, 45.01]]
  // AK omitted — bbox crosses the antimeridian; REGION_CAMERAS handles it
}
const REGION_CAMERAS = {
  AK: { center: [-149.504, 61.342], zoom: 4.9, settleZoom: 5 },
  HI: { center: [-157.0, 20.5], zoom: 4.9, settleZoom: 7 },
  PR: { center: [-66.590, 18.220], zoom: 5, settleZoom: 8 },
  GU: { center: [144.794, 13.444], zoom: 7, settleZoom: 10 },
  MP: { center: [145.674, 15.180], zoom: 7, settleZoom: 9 }
}

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
    this.clickPopup = null
    this.pinnedPwsid = null
    this.stateHoverPopup = null
    this.hoveredStateId = null
    this.hoveredPwsid = null
    this._stateLeaveTimer = null
    this._pwsClickHandled = false
    this.selectedState = null
    this.filteredPwsids = null
    this.mapMode = MODE_NATION
    this.activeFilterRequest = null
    this.geocoderRequestSequence = 0

    this.boundOnFiltersChanged = this.#onFiltersChanged.bind(this)
    this.boundOnResetAll = this.#onResetAll.bind(this)
    this.boundOnReportClick = this.#onReportClick.bind(this)
    document.addEventListener("filters:changed", this.boundOnFiltersChanged)
    document.addEventListener("filter:reset-all", this.boundOnResetAll)
    document.addEventListener("click", this.boundOnReportClick)

    this.map.on("load", () => this.#onLoad())
  }

  disconnect() {
    this.#cancelStateLeaveTimer()
    document.removeEventListener("filters:changed", this.boundOnFiltersChanged)
    document.removeEventListener("filter:reset-all", this.boundOnResetAll)
    document.removeEventListener("click", this.boundOnReportClick)
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
    this.#enterNationMode({ fitDefault: false, syncStateFilter: false })
    this.#restoreStateFromFilter()

    // filter_controller#restoreFromUrl dispatches filters:changed synchronously before
    // map.on("load") completes, so that event is swallowed. Re-apply here to ensure
    // URL-shared filter params are reflected in the map on initial load.
    if (Object.keys(FilterState.get()).length > 0) {
      this.#onFiltersChanged()
    }

    this.#fitDefaultView({ duration: 0 })

    this.map.once("idle", () => {
      if (this.selectedState) this.#fitToState(this.selectedState.stusps)
      this.#hideLoadingMask()
    })
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

      geocoder.on("result", async (ev) => {
        const requestSequence = ++this.geocoderRequestSequence
        const placeType = ev.result.place_type?.[0]
        let zoom = 10
        if (placeType === "region") zoom = 5
        else if (placeType === "district") zoom = 7
        else if (placeType === "place") zoom = 8

        const center = ev.result.geometry.coordinates
        const state = await this.#lookupState(center)
        if (requestSequence !== this.geocoderRequestSequence) return
        if (state) this.#selectState(state)
        this.map.flyTo({ center, zoom })
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
      tiles: [tileUrl],
      promoteId: { states: "geoid", counties: "geoid", places: "geoid", pws: "pwsid" }
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
        "fill-color": ["case", HOVER_STATE_EXPR, "rgb(78, 163, 36)", "#fff"],
        "fill-opacity": ["case", HOVER_STATE_EXPR, 0.2, 0],
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

    // Hover border driven by feature-state — line layers don't have the fill-outline-color
    // tile-boundary artifact, and feature-state means no filter management needed here.
    this.map.addLayer({
      id: "states_hover_outline",
      type: "line",
      source: "wdt",
      "source-layer": "states",
      layout: { visibility: "visible" },
      paint: {
        "line-color": "#999",
        "line-width": ["case", HOVER_STATE_EXPR, 1, 0]
      }
    }, firstLineId)

    this.map.addLayer({
      id: "states_filter",
      type: "line",
      source: "wdt",
      "source-layer": "states",
      layout: { visibility: "visible" },
      paint: { "line-color": "#000", "line-width": 2 },
      filter: EMPTY_STATE_FILTER
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
      minzoom: SERVICE_AREAS_MIN_ZOOM,
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
        "line-color": "#777",
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
      // Cancel any pending mouseleave clear — cursor is still over a state feature.
      this.#cancelStateLeaveTimer()
      const props = this.#statePropsFromEvent(e)
      if (!props) return

      if (this.selectedState) {
        this.#clearStateHover()
        if (this.#stateClickEnabled(props)) {
          this.map.getCanvas().style.cursor = "pointer"
          this.#showStatePrompt(e.lngLat)
        } else {
          this.map.getCanvas().style.cursor = ""
          this.#removeStatePrompt()
        }
        return
      }

      if (!this.#stateHoverEnabled()) {
        this.map.getCanvas().style.cursor = ""
        this.#clearStateHover()
        this.#removeStatePrompt()
        return
      }

      this.map.getCanvas().style.cursor = "pointer"
      if (props.geoid !== this.hoveredStateId) {
        this.#clearStateHover()
        this.hoveredStateId = props.geoid
        this.map.setFeatureState(
          { source: "wdt", sourceLayer: "states", id: this.hoveredStateId },
          { hover: true }
        )
      }

      if (this.#shouldShowStatePrompt(props)) {
        this.#showStatePrompt(e.lngLat)
      } else {
        this.#removeStatePrompt()
      }
    })

    this.map.on("mouseleave", "states", () => {
      // Debounce the clear so a cursor crossing a tile-boundary gap between two states
      // doesn't produce a visible flicker (mousemove on the next state cancels this).
      this._stateLeaveTimer = setTimeout(() => {
        this._stateLeaveTimer = null
        this.map.getCanvas().style.cursor = ""
        this.#clearStateHover()
        this.#removeStatePrompt()
      }, 100)
    })

    this.map.on("click", "states", (e) => {
      if (this.#handleRenderedPwsClick(e)) return

      const props = this.#statePropsFromEvent(e)
      if (!props) return
      if (!this.#stateClickEnabled(props)) return

      const wasNationMode = this.mapMode === MODE_NATION
      const switchingState = !!this.selectedState && this.selectedState.stusps !== props.stusps
      this.#selectState(props)
      this.#removeStatePrompt()

      if (wasNationMode || switchingState || this.map.getZoom() < STATE_ENTRY_ZOOM) {
        if (!this.#fitToState(props.stusps)) {
          this.map.flyTo({ center: e.lngLat, zoom: Math.max(this.map.getZoom(), STATE_ENTRY_ZOOM) })
        }
      }
    })

    // ── PWS polygon hover ─────────────────────────────────────────────────────

    this.map.on("mousemove", "pws", (e) => {
      if (!this.selectedState) return

      this.map.getCanvas().style.cursor = "pointer"
      const props = e.features[0].properties

      if (props.pwsid === this.hoveredPwsid) return
      this.hoveredPwsid = props.pwsid
      this.map.setFilter("pws_hover", ["in", "pwsid", props.pwsid])

      if (this.hoverPopup) {
        this.hoverPopup.remove()
        this.hoverPopup = null
      }

      if (props.pwsid === this.pinnedPwsid) return

      const html = this.#buildPopupHtml(props)
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
      if (!this.selectedState) return

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
      this.map.setFilter("pws_hover", EMPTY_PWS_FILTER)
      this.#removeStatePrompt()
      if (this.hoverPopup) {
        this.hoverPopup.remove()
        this.hoverPopup = null
      }
    })

    this.map.on("zoomend", () => this.#syncModeFromZoom())

    // ── PWS polygon click ───────────────────────────────────────────────────

    this.map.on("click", "pws", (e) => this.#handlePwsClick(e))
    this.map.on("click", (e) => {
      if (this.#handleRenderedPwsClick(e)) return
      if (this.clickPopup) this.clickPopup.remove()
    })


  }

  zoom48() {
    const input = document.querySelector(".mapboxgl-ctrl-geocoder--input")
    if (input) input.value = ""
    this.#enterNationMode()
  }

  zoomAk() {
    this.#zoomRegion("AK")
  }

  zoomHi() {
    this.#zoomRegion("HI")
  }

  zoomPr() {
    this.#zoomRegion("PR")
  }

  zoomGu() {
    this.#zoomRegion("GU")
  }

  zoomMp() {
    this.#zoomRegion("MP")
  }

  #zoomRegion(regionKey) {
    const state = REGION_STATES[regionKey]
    const camera = REGION_CAMERAS[regionKey]
    if (!state || !camera) return

    this.#selectState(state)
    this.map.flyTo({ center: camera.center, zoom: camera.zoom })
    this.map.once("idle", () => {
      this.map.flyTo({ zoom: camera.settleZoom, duration: 3600 })
    })
  }

  #onResetAll() {
    if (!this.selectedState && !FilterState.get().state) return
    this.#enterNationMode({ fitDefault: false, resetMaxZoom: false })
    if (this.map.getZoom() > NATION_MAX_ZOOM) {
      this.map.easeTo({ zoom: NATION_MAX_ZOOM, duration: 400 })
      this.map.once("moveend", () => this.map.setMaxZoom(NATION_MAX_ZOOM))
    } else {
      this.map.setMaxZoom(NATION_MAX_ZOOM)
    }
  }

  async #onFiltersChanged() {
    if (!this.map?.getLayer("pws")) return

    const filters = FilterState.get()
    const filterParamsWithoutState = this.#filterParamsWithoutMapState()
    this.#abortActiveFilterRequest()

    if (Object.keys(filters).length === 0) {
      this.filteredPwsids = null
      this.#applyPwsFilters()
      this.#reloadStatsFrame()
      return
    }

    if ([...filterParamsWithoutState.keys()].length === 0) {
      this.filteredPwsids = null
      this.#applyPwsFilters()
      this.#reloadStatsFrame()
      return
    }

    const request = new AbortController()
    this.activeFilterRequest = request

    try {
      const res = await fetch(`/map?${filterParamsWithoutState.toString()}`, {
        signal: request.signal
      })
      if (!res.ok) return

      const { pwsids } = await res.json()
      if (this.activeFilterRequest !== request) return
      if (!this.map) return

      this.filteredPwsids = pwsids
      this.#applyPwsFilters()
      this.#reloadStatsFrame()
    } catch (err) {
      if (err.name !== "AbortError") console.error("[map] filter fetch failed", err)
    }
  }

  #abortActiveFilterRequest() {
    if (!this.activeFilterRequest) return
    this.activeFilterRequest.abort()
    this.activeFilterRequest = null
  }

  #enterNationMode({ fitDefault = true, syncStateFilter = true, resetMaxZoom = true } = {}) {
    const hadStateScope = !!this.selectedState || !!FilterState.get().state || !!FilterState.get().state_name
    this.selectedState = null
    delete this.element.dataset.selectedState
    delete this.element.dataset.selectedStateName
    this.mapMode = MODE_NATION
    if (resetMaxZoom) this.map.setMaxZoom(NATION_MAX_ZOOM)
    this.map.setFilter("states_filter", EMPTY_STATE_FILTER)
    this.#clearStateHover()
    this.map.setFilter("pws_hover", EMPTY_PWS_FILTER)
    this.#removeStatePrompt()
    this.#removeSystemPopups()
    this.#applyPwsFilters()
    if (syncStateFilter && hadStateScope) this.#clearStateFilter()
    this.#reloadStatsFrame()
    if (fitDefault) this.#fitDefaultView()
  }

  #selectState(props, { syncStateFilter = true } = {}) {
    const state = this.#normalizeStateProps(props)
    if (!state) return

    this.map.setMaxZoom(UNLOCKED_MAX_ZOOM)
    this.selectedState = state
    this.element.dataset.selectedState = state.stusps
    this.element.dataset.selectedStateName = state.name
    this.mapMode = this.#systemsModeActive() ? MODE_SYSTEMS : MODE_STATE
    this.#clearStateHover()
    this.map.setFilter("states_filter", this.#stateBoundaryFilter(state))
    this.map.setFilter("pws_hover", EMPTY_PWS_FILTER)
    this.#removeSystemPopups()
    this.#applyPwsFilters()
    if (syncStateFilter) {
      this.#setStateFilter(state)
    } else {
      this.#reloadStatsFrame()
    }
  }

  #syncModeFromZoom() {
    if (!this.selectedState) return

    if (this.map.getZoom() < STATE_EXIT_ZOOM) {
      // Keep selectedState intact on zoom-out so the URL and PWS filter stay scoped to this state.
      this.mapMode = MODE_NATION
      this.#clearStateHover()
      this.map.getCanvas().style.cursor = ""
      this.#removeStatePrompt()
      return
    }

    const nextMode = this.#systemsModeActive() ? MODE_SYSTEMS : MODE_STATE
    this.mapMode = nextMode
    this.#clearStateHover()
    if (nextMode === MODE_SYSTEMS) {
      this.map.getCanvas().style.cursor = ""
      this.#removeStatePrompt()
    }
  }

  #systemsModeActive() {
    return !!this.selectedState && this.map.getZoom() >= SYSTEMS_ENTRY_ZOOM
  }

  #handleRenderedPwsClick(event) {
    if (this.#pwsClickAlreadyHandled(event)) return true
    if (!this.map?.getLayer("pws")) return false
    if (typeof this.map.queryRenderedFeatures !== "function") return false

    const box = this.#pwsClickHitBox(event)
    if (!box) return false

    const feature = this.map.queryRenderedFeatures(box, { layers: ["pws"] })[0]
    if (!feature) return false

    return this.#handlePwsClick({ ...event, features: [feature] })
  }

  #handlePwsClick(event) {
    if (this.#pwsClickAlreadyHandled(event)) return true

    const props = event.features?.[0]?.properties
    if (!props?.pwsid) return false

    if (!this.selectedState) {
      if (!props.stusps) return false

      this.#markPwsClickHandled(event)
      this.#selectState({ stusps: props.stusps, name: props.stusps })
      if (!this.#fitToState(props.stusps)) {
        this.map.flyTo({ center: event.lngLat, zoom: Math.max(this.map.getZoom(), STATE_ENTRY_ZOOM) })
      }
      return true
    }

    this.#markPwsClickHandled(event)

    if (!this.#systemsModeActive()) {
      this.map.flyTo({ center: event.lngLat, zoom: 8.5 })
      return true
    }

    if (this.hoverPopup) {
      this.hoverPopup.remove()
      this.hoverPopup = null
    }
    if (this.clickPopup) this.clickPopup.remove()

    this.pinnedPwsid = props.pwsid
    this.clickPopup = new window.mapboxgl.Popup({
      closeButton: true,
      closeOnClick: false,
      className: "min-w-[280px]",
      maxWidth: "400px"
    })
      .setLngLat(event.lngLat)
      .setHTML(this.#buildPopupHtml(props, { showReport: true }))
      .addTo(this.map)

    this.clickPopup.on("close", () => {
      this.clickPopup = null
      this.pinnedPwsid = null
    })
    return true
  }

  #pwsClickHitBox(event) {
    const point = event?.point
    if (!point) return null

    const tolerance = 5
    return [
      [point.x - tolerance, point.y - tolerance],
      [point.x + tolerance, point.y + tolerance]
    ]
  }

  #pwsClickAlreadyHandled(event) {
    return !!(event?.__wdtPwsClickHandled || event?.originalEvent?.__wdtPwsClickHandled)
  }

  #markPwsClickHandled(event) {
    if (event) event.__wdtPwsClickHandled = true
    if (event?.originalEvent) event.originalEvent.__wdtPwsClickHandled = true
  }

  #stateHoverEnabled() {
    return !this.selectedState && this.mapMode === MODE_NATION
  }

  #stateClickEnabled(props) {
    return !this.selectedState || !this.#stateIsSelected(props)
  }

  #stateIsSelected(props) {
    return !!this.selectedState && props.stusps === this.selectedState.stusps
  }

  #statePropsFromEvent(event) {
    return this.#normalizeStateProps(event?.features?.[0]?.properties)
  }

  #normalizeStateProps(props) {
    if (!props?.stusps) return null

    return {
      stusps: props.stusps,
      name: props.name || props.stusps,
      geoid: props.geoid || null
    }
  }

  #fitToState(stusps) {
    const leftInset = this.#sidebarLeftInset()
    const padding = leftInset ? { top: 60, bottom: 60, right: 60, left: leftInset + 60 } : 60
    const fitOptions = { padding, maxZoom: SYSTEMS_ENTRY_ZOOM - 0.01 }

    if (STATE_FIT_BOUNDS[stusps]) {
      this.map.fitBounds(STATE_FIT_BOUNDS[stusps], fitOptions)
      return true
    }

    const features = this.map.querySourceFeatures("wdt", {
      sourceLayer: "states",
      filter: ["==", "stusps", stusps]
    })
    if (!features.length) return false

    // querySourceFeatures returns one entry per tile, so dedup by feature id
    // to avoid iterating the same geometry multiple times for large states.
    const seen = new Set()
    const bounds = new window.mapboxgl.LngLatBounds()
    features.forEach(({ id, geometry }) => {
      if (id !== undefined && seen.has(id)) return
      if (id !== undefined) seen.add(id)
      const polygons = geometry.type === "MultiPolygon"
        ? geometry.coordinates
        : [geometry.coordinates]
      polygons.forEach(rings => rings[0].forEach(c => bounds.extend(c)))
    })

    if (bounds.isEmpty()) return false
    this.map.fitBounds(bounds, fitOptions)
    return true
  }

  #restoreStateFromFilter() {
    const filters = FilterState.get()
    if (!filters.state) return

    this.#selectState({
      stusps: filters.state,
      name: filters.state_name || filters.state
    }, { syncStateFilter: false })
  }

  #cancelStateLeaveTimer() {
    if (!this._stateLeaveTimer) return
    clearTimeout(this._stateLeaveTimer)
    this._stateLeaveTimer = null
  }

  #clearStateHover() {
    if (this.hoveredStateId === null) return
    this.map.setFeatureState(
      { source: "wdt", sourceLayer: "states", id: this.hoveredStateId },
      { hover: false }
    )
    this.hoveredStateId = null
  }

  #stateBoundaryFilter(state) {
    if (state.geoid) return ["==", ["get", "geoid"], state.geoid]
    return ["==", ["get", "stusps"], state.stusps]
  }

  #applyPwsFilters() {
    if (!this.map?.getLayer("pws")) return

    const expr = this.#pwsFilterExpression()
    this.map.setFilter("pws", expr)
    this.map.setFilter("pws_outline", expr)
  }

  #pwsFilterExpression() {
    if (!this.selectedState) {
      if (this.filteredPwsids === null) return null
      if (this.filteredPwsids.length === 0) return EMPTY_PWS_FILTER

      return ["in", "pwsid", ...this.filteredPwsids]
    }

    const stateExpr = ["==", "stusps", this.selectedState.stusps]
    if (this.filteredPwsids === null) return stateExpr
    if (this.filteredPwsids.length === 0) return EMPTY_PWS_FILTER

    return ["all", stateExpr, ["in", "pwsid", ...this.filteredPwsids]]
  }

  #reloadStatsFrame() {
    syncStatsFrame()
  }

  #filterParamsWithoutMapState() {
    const params = new URLSearchParams(FilterState.toUrlParams())
    params.delete("state")
    params.delete("state_name")
    return params
  }

  #setStateFilter(state) {
    FilterState.set({
      ...FilterState.get(),
      state: state.stusps,
      state_name: state.name
    })
    syncToUrl()
    document.dispatchEvent(new CustomEvent("filters:changed"))
  }

  #clearStateFilter() {
    const filters = { ...FilterState.get() }
    delete filters.state
    delete filters.state_name
    FilterState.set(filters)
    syncToUrl()
    document.dispatchEvent(new CustomEvent("filters:changed"))
  }

  async #lookupState(center) {
    if (!center) return null

    try {
      const params = new URLSearchParams({ lng: center[0], lat: center[1] })
      const res = await fetch(`/states/lookup?${params.toString()}`)
      if (!res.ok) return null
      return await res.json()
    } catch (err) {
      console.error("[map] state lookup failed", err)
      return null
    }
  }

  #shouldShowStatePrompt(props) {
    return this.mapMode === MODE_NATION || !this.#stateIsSelected(props)
  }

  #showStatePrompt(lngLat) {
    if (!this.stateHoverPopup) {
      this.stateHoverPopup = new window.mapboxgl.Popup({
        closeButton: false,
        closeOnClick: false,
        className: "map-state-hover",
        maxWidth: "240px"
      }).setHTML('<span class="block px-4 py-3 text-sm font-medium">Select a state to learn more</span>')
    }

    this.stateHoverPopup.setLngLat(lngLat).addTo(this.map)
  }

  #removeStatePrompt() {
    if (!this.stateHoverPopup) return
    this.stateHoverPopup.remove()
    this.stateHoverPopup = null
  }

  #removeSystemPopups() {
    if (this.hoverPopup) {
      this.hoverPopup.remove()
      this.hoverPopup = null
    }
    if (this.clickPopup) {
      this.clickPopup.remove()
      this.clickPopup = null
    }
    this.pinnedPwsid = null
  }

  #buildPopupHtml(props, { showType = false, showReport = false, reportLabel = "View Full Report" } = {}) {
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
      if (link) {
        link.textContent = reportLabel
        if (props.pwsid) {
          link.href = this.#reportPath(props.pwsid)
          link.dataset.pwsid = props.pwsid
        }
      }
    }

    return root.outerHTML
  }

  #reportPath(pwsid) {
    return `/public_water_systems/${encodeURIComponent(pwsid)}/report`
  }

  #onReportClick(e) {
    const link = e.target?.closest?.(".js-view-report")
    if (!link) return
    e.preventDefault()
    const pwsid = link.dataset.pwsid
    if (!pwsid) return
    this.#removeSystemPopups()
    this.#openReport(pwsid)
  }

  #openReport(pwsid) {
    const overlay = document.getElementById("container-report")
    overlay?.classList.remove("hidden")
    Turbo.visit(this.#reportPath(pwsid), { frame: "report-body" })
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
