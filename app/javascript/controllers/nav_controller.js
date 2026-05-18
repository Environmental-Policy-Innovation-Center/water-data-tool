import { Controller } from "@hotwired/stimulus"

// Handles section navigation.
//
// The map is always rendered as a background; #container-map is never hidden.
// Map vs Table: toggles .table-mode on #container-map — CSS hides/shows #map
// vs #container-table accordingly.
// Non-map/table sections (datasets, documentation, downloads): toggles
// .section-mode on #container-map (for overlay styling) and shows the matching
// .container-main-content element.
export default class extends Controller {
  connect() {
    this._tableContainer = document.getElementById("container-table")
  }

  toggleMobile(event) {
    event.preventDefault()
    const menu = document.getElementById("container-mobile-menu")
    const btn = document.getElementById("mobile-menu-toggle")
    if (!menu || !btn) return

    const isOpen = !btn.classList.contains("closed")
    if (isOpen) {
      this.#closeMobileMenu()
    } else {
      btn.classList.remove("closed")
      btn.setAttribute("aria-expanded", "true")
      menu.classList.remove("hidden")
      btn.querySelector(".mm-icon-bars")?.classList.add("hidden")
      btn.querySelector(".mm-icon-x")?.classList.remove("hidden")
    }
  }

  show(event) {
    event.preventDefault()
    const section = event.currentTarget.dataset.section
    if (!section) return

    const containerMap = document.getElementById("container-map")

    document.querySelectorAll(".container-main-content").forEach(el => el.classList.add("hidden"))

    // Map is always visible as background; section cards float on top of it
    containerMap.classList.remove("hidden")
    containerMap.classList.toggle("table-mode", section === "table")
    containerMap.classList.toggle("section-mode", section !== "map" && section !== "table")

    if (this._tableContainer) {
      const isTable = section === "table"
      this._tableContainer.classList.toggle("hidden", !isTable)
      this._tableContainer.classList.toggle("flex", isTable)
      this._tableContainer.classList.toggle("flex-col", isTable)
    }

    // In table mode, pin the filter bar inside the card so it acts as the card header
    const filterBar = document.querySelector("#container-map-ui-top")
    if (filterBar) {
      if (section === "table") {
        filterBar.style.setProperty("top", "12px") // matches card's top-3
        filterBar.style.setProperty("right", "16px") // matches card's right-4
      } else {
        filterBar.style.removeProperty("top")
        filterBar.style.removeProperty("right")
      }
    }

    if (section === "table") {
      document.dispatchEvent(new CustomEvent("table:show"))
    } else if (section !== "map") {
      const target = document.getElementById(`container-${section}`)
      if (target) target.classList.remove("hidden")
    }

    document.querySelectorAll("[data-section]").forEach(el => {
      el.classList.toggle("active", el.dataset.section === section)
    })

    document.querySelectorAll("#container-sidebar [data-section]").forEach((el) => {
      if (el.classList.contains("active")) {
        el.setAttribute("aria-current", "page")
      } else {
        el.removeAttribute("aria-current")
      }
    })

    this.#closeMobileMenu()
  }

  toggleMobileFilters() {
    if (window.innerWidth >= 640) return
    const el = document.getElementById("container-map-ui-top")
    if (!el) return
    const isHidden = window.getComputedStyle(el).display === "none"
    if (isHidden) {
      el.style.setProperty("display", "block")
      el.style.setProperty("position", "absolute")
      el.style.setProperty("top", "0")
      el.style.setProperty("left", "0")
      el.style.setProperty("right", "0")
      el.style.setProperty("z-index", "10")
    } else {
      el.style.removeProperty("display")
      el.style.removeProperty("position")
      el.style.removeProperty("top")
      el.style.removeProperty("left")
      el.style.removeProperty("right")
      el.style.removeProperty("z-index")
    }
  }

  toggleMobileStats() {
    if (window.innerWidth >= 640) return
    const el = document.querySelector("turbo-frame#stats-bar > div")
    if (!el) return
    const isHidden = window.getComputedStyle(el).display === "none"
    el.style.setProperty("display", isHidden ? "block" : "none")
  }

  #closeMobileMenu() {
    const btn = document.getElementById("mobile-menu-toggle")
    if (!btn || btn.classList.contains("closed")) return

    const menu = document.getElementById("container-mobile-menu")
    if (!menu) return
    menu.classList.add("hidden")
    btn.classList.add("closed")
    btn.setAttribute("aria-expanded", "false")
    btn.querySelector(".mm-icon-bars")?.classList.remove("hidden")
    btn.querySelector(".mm-icon-x")?.classList.add("hidden")
  }
}
