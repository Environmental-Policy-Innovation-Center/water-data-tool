import { Controller } from "@hotwired/stimulus"

const FULL_WIDTH = 250
const COLLAPSED_WIDTH = 80
const SIDEBAR_LEFT = 16      // matches left-4 (16px)
const CONTROLS_GAP = 16      // gap between sidebar right edge and content — matches SIDEBAR_LEFT so all three outer gaps are equal
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
    this.#shiftContent(width)
  }

  #shiftContent(sidebarWidth) {
    const base = sidebarWidth + SIDEBAR_LEFT + CONTROLS_GAP

    if (window.innerWidth < 640) {
      // Sidebar is hidden on mobile — reset any inline styles set at desktop width so
      // Tailwind responsive classes (max-[640px]:left-0 etc.) can take over.
      document.querySelector("#container-map-ui-top")?.style.removeProperty("left")
      document.querySelector(".mapboxgl-ctrl-top-left")?.style.removeProperty("margin-left")
      document.querySelector("#container-region-nav")?.style.removeProperty("left")
      ;["#container-datasets", "#container-documentation", "#container-downloads"].forEach(id => {
        const el = document.querySelector(id)
        if (!el) return
        el.style.removeProperty("left")
        el.style.removeProperty("right")
        el.style.removeProperty("width")
      })
      return
    }

    // Map UI overlay elements (filter bar, mapbox controls, region nav)
    document.querySelector("#container-map-ui-top")?.style.setProperty("left", `${base}px`)
    document.querySelector(".mapboxgl-ctrl-top-left")?.style.setProperty("margin-left", `${base}px`)
    // Zoom buttons sit INSIDE .mapboxgl-ctrl-top-left at padding:10px from its edge
    document.querySelector("#container-region-nav")?.style.setProperty("left", `${base + MAPBOX_CTRL_PAD}px`)

    // Section containers (datasets, documentation, downloads) — shift right of sidebar
    ;["#container-datasets", "#container-documentation", "#container-downloads"].forEach(id => {
      const el = document.querySelector(id)
      if (!el) return
      el.style.setProperty("left", `${base}px`)
      el.style.setProperty("right", `${SIDEBAR_LEFT}px`)
      el.style.setProperty("width", "auto")
    })

    // Table panel (inside #container-map) — also needs to clear the sidebar
    document.querySelector("#container-table")?.style.setProperty("left", `${base}px`)
  }
}
