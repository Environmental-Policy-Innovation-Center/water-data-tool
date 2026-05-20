import { Controller } from "@hotwired/stimulus"

// Handles section navigation and mobile panel state.
//
// #activePanel tracks which mobile overlay is open: null | "filters" | "stats"
// All state changes go through #setActivePanel so FABs, dropdowns, and the
// stats bar stay in sync. Only one panel can be active at a time.
export default class extends Controller {
  #activePanel = null

  connect() {
    this._tableContainer = document.getElementById("container-table")
    this.#watchFilterPanelState()
    // Re-apply stats visibility after Turbo reloads the stats frame
    document.getElementById("stats-bar")?.addEventListener("turbo:frame-load", () => {
      if (this.#activePanel === "stats") this.#applyStatsDisplay(true)
    })
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

  toggleMobileFilterPanel(event) {
    if (window.innerWidth >= 640) return
    event.stopPropagation()
    this.#setActivePanel(this.#activePanel === "filters" ? null : "filters")
  }

  toggleMobileStats() {
    if (window.innerWidth >= 640) return
    this.#setActivePanel(this.#activePanel === "stats" ? null : "stats")
  }

  showMobileStats() {
    if (window.innerWidth >= 640) return
    this.#setActivePanel("stats")
  }

  #setActivePanel(panel) {
    const prev = this.#activePanel
    this.#activePanel = panel

    if (prev === "filters" && panel !== "filters") this.#closeFilterDropdown()
    if (panel === "filters" && prev !== "filters") this.#openFilterDropdown()

    this.#applyStatsDisplay(panel === "stats")
    this.#setFabActive("btn-mobile-filter", panel === "filters")
    this.#setFabActive("btn-mobile-stats", panel === "stats")
  }

  #openFilterDropdown() {
    const moreBtn = document.getElementById("container-menu-btn-10")
    if (!moreBtn) return
    const panel = document.getElementById("container-menu-10")
    if (panel && !panel.classList.contains("hidden")) return
    moreBtn.click()
    // filter-menu#toggleMenu sets inline style.left via JS positioning — remove it on mobile
    // so the CSS max-sm:left-2/right-2 constraints take over instead
    if (panel && !panel.classList.contains("hidden")) panel.style.removeProperty("left")
  }

  #closeFilterDropdown() {
    const moreBtn = document.getElementById("container-menu-btn-10")
    if (!moreBtn) return
    const panel = document.getElementById("container-menu-10")
    if (!panel || panel.classList.contains("hidden")) return
    moreBtn.click()
  }

  #applyStatsDisplay(show) {
    const el = document.querySelector("turbo-frame#stats-bar > div") ||
               document.getElementById("container-how-to-use")
    if (!el) return
    if (show) {
      el.style.setProperty("display", "block")
    } else {
      el.style.removeProperty("display")
    }
  }

  // Keeps #activePanel in sync when the filter dropdown is opened/closed by means
  // other than the FAB (e.g. tapping a filter tab directly, or outside-click close).
  #watchFilterPanelState() {
    const moreBtn = document.getElementById("container-menu-btn-10")
    if (!moreBtn) return
    new MutationObserver(() => {
      if (window.innerWidth >= 640) return
      const isOpen = moreBtn.getAttribute("aria-expanded") === "true"
      if (!isOpen && this.#activePanel === "filters") {
        this.#activePanel = null
        this.#setFabActive("btn-mobile-filter", false)
      } else if (isOpen && this.#activePanel !== "filters") {
        this.#activePanel = "filters"
        this.#applyStatsDisplay(false)
        this.#setFabActive("btn-mobile-filter", true)
        this.#setFabActive("btn-mobile-stats", false)
      }
    }).observe(moreBtn, { attributes: true, attributeFilter: ["aria-expanded"] })
  }

  #setFabActive(id, active) {
    const el = document.getElementById(id)
    if (!el) return
    if (active) {
      el.dataset.active = ""
    } else {
      delete el.dataset.active
    }
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
