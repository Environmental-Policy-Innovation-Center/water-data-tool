import { Controller } from "@hotwired/stimulus"

// Handles section navigation.
//
// Map and Table views share #container-map (so the filter bar stays visible).
// Switching between them toggles the .table-mode class on #container-map —
// CSS hides/shows #map vs #container-table accordingly.
//
// All other sections (datasets, documentation, downloads) use the standard
// .container-main-content show/hide approach.
export default class extends Controller {
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
      menu.style.display = "block"
      btn.querySelector(".mm-icon-bars")?.classList.add("hidden")
      btn.querySelector(".mm-icon-x")?.classList.remove("hidden")
    }
  }

  show(event) {
    event.preventDefault()
    const section = event.currentTarget.dataset.section
    if (!section) return

    const containerMap = document.getElementById("container-map")

    if (section === "map" || section === "table") {
      // Hide all top-level sections, then restore container-map
      document.querySelectorAll(".container-main-content").forEach(el => {
        el.classList.add("hidden")
      })
      containerMap.classList.remove("hidden")

      // Toggle map vs table mode (CSS handles #map / #container-table visibility)
      containerMap.classList.toggle("table-mode", section === "table")

      if (section === "table") {
        document.dispatchEvent(new CustomEvent("table:show"))
      }
    } else {
      // Standard section switching — hide everything, show target
      document.querySelectorAll(".container-main-content").forEach(el => {
        el.classList.add("hidden")
      })
      const target = document.getElementById(`container-${section}`)
      if (target) target.classList.remove("hidden")
    }

    document.querySelectorAll("[data-section]").forEach(el => {
      el.classList.toggle("active", el.dataset.section === section)
    })

    document.querySelectorAll("#container-sidebar a[data-section]").forEach((el) => {
      if (el.classList.contains("active")) {
        el.setAttribute("aria-current", "page")
      } else {
        el.removeAttribute("aria-current")
      }
    })

    this.#closeMobileMenu()
  }

  #closeMobileMenu() {
    const btn = document.getElementById("mobile-menu-toggle")
    if (!btn || btn.classList.contains("closed")) return

    const menu = document.getElementById("container-mobile-menu")
    if (!menu) return
    menu.style.display = "none"
    btn.classList.add("closed")
    btn.querySelector(".mm-icon-bars")?.classList.remove("hidden")
    btn.querySelector(".mm-icon-x")?.classList.add("hidden")
  }
}
