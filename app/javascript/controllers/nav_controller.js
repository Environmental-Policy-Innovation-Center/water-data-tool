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
  }
}
