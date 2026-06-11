import { Controller } from "@hotwired/stimulus"
import * as FilterState from "filter_state"
import { syncStatsFrame } from "stats_frame"

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
const SERVICE_AREAS_MIN_ZOOM = 5
const STATE_ENTRY_ZOOM = 6
const STATE_EXIT_ZOOM = 4.55
const SYSTEMS_ENTRY_ZOOM = 8
const UNLOCKED_MAX_ZOOM = 22
const MODE_NATION = "nation"
const MODE_STATE = "state"
const MODE_SYSTEMS = "systems"
const EMPTY_PWS_FILTER = ["in", "pwsid", ""]
const EMPTY_STATE_FILTER = ["==", ["get", "geoid"], ""]
const REGION_STATES = {
  AK: { stusps: "AK", name: "Alaska", geoid: "02" },
  HI: { stusps: "HI", name: "Hawaii", geoid: "15" },
  PR: { stusps: "PR", name: "Puerto Rico", geoid: "72" },
  GU: { stusps: "GU", name: "Guam", geoid: "66" },
  MP: { stusps: "MP", name: "Northern Mariana Islands", geoid: "69" }
}
const REGION_CAMERAS = {
  AK: { center: [-149.504, 61.342], zoom: 4.9, settleZoom: 5 },
  HI: { center: [-157.856, 21.305], zoom: 4.9, settleZoom: 6 },
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
    this.stateHoverPopup = null
    this.hoveredPwsid = null
    this.selectedState = null
    this.filteredPwsids = null
    this.mapMode = MODE_NATION
    this.activeFilterRequest = null
    this.geocoderRequestSequence = 0

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
      filter: EMPTY_STATE_FILTER
    })

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
      if (this.#systemsModeActive()) return

      const props = this.#statePropsFromEvent(e)
      if (!props) return

      this.map.getCanvas().style.cursor = "pointer"
      this.map.setFilter("states_hover", ["==", ["get", "geoid"], props.geoid])

      if (this.#shouldShowStatePrompt(props)) {
        this.#showStatePrompt(e.lngLat)
      } else {
        this.#removeStatePrompt()
      }
    })

    this.map.on("mouseleave", "states", () => {
      this.map.getCanvas().style.cursor = ""
      this.map.setFilter("states_hover", EMPTY_STATE_FILTER)
      this.#removeStatePrompt()
    })

    this.map.on("click", "states", (e) => {
      if (this.#systemsModeActive()) return

      const props = this.#statePropsFromEvent(e)
      if (!props) return

      const wasNationMode = this.mapMode === MODE_NATION
      this.#selectState(props)
      this.#removeStatePrompt()

      if (wasNationMode) {
        this.map.flyTo({ center: e.lngLat, zoom: Math.max(this.map.getZoom(), STATE_ENTRY_ZOOM) })
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

    // ── PWS polygon click → detail popup with "View Full Report" ───────────

    this.map.on("click", "pws", (e) => {
      if (!this.selectedState) return

      if (!this.#systemsModeActive()) {
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

      if (this.clickPopup) this.clickPopup.remove()
      this.clickPopup = null
      this.#openReport(props.pwsid)
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

  #enterNationMode({ fitDefault = true, syncStateFilter = true } = {}) {
    const hadStateScope = !!this.selectedState || !!FilterState.get().state || !!FilterState.get().state_name
    this.selectedState = null
    delete this.element.dataset.selectedState
    delete this.element.dataset.selectedStateName
    this.mapMode = MODE_NATION
    this.map.setMaxZoom(NATION_MAX_ZOOM)
    this.map.setFilter("states_filter", EMPTY_STATE_FILTER)
    this.map.setFilter("states_hover", EMPTY_STATE_FILTER)
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
    this.map.setFilter("states_hover", EMPTY_STATE_FILTER)
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
      this.#enterNationMode({ fitDefault: false })
      return
    }

    this.mapMode = this.#systemsModeActive() ? MODE_SYSTEMS : MODE_STATE
  }

  #systemsModeActive() {
    return !!this.selectedState && this.map.getZoom() >= SYSTEMS_ENTRY_ZOOM
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

  #restoreStateFromFilter() {
    const filters = FilterState.get()
    if (!filters.state) return

    this.#selectState({
      stusps: filters.state,
      name: filters.state_name || filters.state
    }, { syncStateFilter: false })
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
    if (!this.selectedState) return EMPTY_PWS_FILTER

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
    this.#syncFiltersToUrl()
    document.dispatchEvent(new CustomEvent("filters:changed"))
  }

  #clearStateFilter() {
    const filters = { ...FilterState.get() }
    delete filters.state
    delete filters.state_name
    FilterState.set(filters)
    this.#syncFiltersToUrl()
    document.dispatchEvent(new CustomEvent("filters:changed"))
  }

  #syncFiltersToUrl() {
    const url = new URL(window.location)
    url.search = FilterState.toUrlParams().toString()
    history.replaceState({}, "", url)
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
    return this.mapMode === MODE_NATION || props.stusps !== this.selectedState?.stusps
  }

  #showStatePrompt(lngLat) {
    if (!this.stateHoverPopup) {
      this.stateHoverPopup = new window.mapboxgl.Popup({
        closeButton: false,
        closeOnClick: false,
        className: "map-state-hover",
        maxWidth: "240px"
      }).setHTML('<span class="text-sm font-medium">Select a state to learn more</span>')
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
  }

  #openReport(pwsid) {
    const overlay = document.getElementById("container-report")
    if (overlay) overlay.classList.remove("hidden")

    if (document.querySelector("turbo-frame#report-body")) {
      Turbo.visit(this.#reportPath(pwsid), {frame: "report-body"})
    }
  }

  #buildHoverHtml(props) {
    return this.#buildPopupHtml(props, {
      showReport: this.#systemsModeActive(),
      reportLabel: "Click to Open Report"
    })
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
        if (props.pwsid) link.href = this.#reportPath(props.pwsid)
      }
    }

    return root.outerHTML
  }

  #reportPath(pwsid) {
    return `/public_water_systems/${encodeURIComponent(pwsid)}/report`
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
