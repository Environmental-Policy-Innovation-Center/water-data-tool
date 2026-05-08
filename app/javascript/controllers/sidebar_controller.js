import { Controller } from "@hotwired/stimulus"

const FULL_WIDTH = 250
const COLLAPSED_WIDTH = 80
const SIDEBAR_LEFT = 16      // matches left-4 (16px)
const CONTROLS_GAP = 8       // gap between sidebar right edge and map controls
const MAPBOX_CTRL_PAD = 10   // Mapbox adds padding:10px to .mapboxgl-ctrl-top-left
const AUTO_COLLAPSE_BELOW = 1280

export default class extends Controller {
  #resizeTimer = null
  #userSet = false

  connect() {
    const saved = localStorage.getItem("sidebar-collapsed")
    // Do NOT set #userSet here — only manual toggles should lock out auto-collapse
    const collapsed = saved !== null ? saved === "true" : window.innerWidth < AUTO_COLLAPSE_BELOW
    this.#apply(collapsed)
  }

  toggle() {
    this.#userSet = true
    this.#apply(!this.#collapsed)
    localStorage.setItem("sidebar-collapsed", this.#collapsed)
  }

  handleResize() {
    clearTimeout(this.#resizeTimer)
    this.#resizeTimer = setTimeout(() => {
      if (this.#userSet) return
      const shouldCollapse = window.innerWidth < AUTO_COLLAPSE_BELOW
      if (shouldCollapse !== this.#collapsed) this.#apply(shouldCollapse)
    }, 100)
  }

  get #collapsed() {
    return this.element.hasAttribute("data-sidebar-collapsed")
  }

  #apply(collapsed) {
    const width = collapsed ? COLLAPSED_WIDTH : FULL_WIDTH
    if (collapsed) {
      this.element.setAttribute("data-sidebar-collapsed", "")
    } else {
      this.element.removeAttribute("data-sidebar-collapsed")
    }
    this.element.style.width = `${width}px`
    this.#shiftMapControls(width)
  }

  #shiftMapControls(sidebarWidth) {
    const base = sidebarWidth + SIDEBAR_LEFT + CONTROLS_GAP
    document.querySelector("#container-map-ui-top")?.style.setProperty("left", `${base}px`)
    document.querySelector(".mapboxgl-ctrl-top-left")?.style.setProperty("margin-left", `${base}px`)
    // Zoom buttons sit INSIDE .mapboxgl-ctrl-top-left at padding:10px from its edge
    document.querySelector("#container-region-nav")?.style.setProperty("left", `${base + MAPBOX_CTRL_PAD}px`)
  }
}
