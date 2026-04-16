import { Controller } from "@hotwired/stimulus"

// Handles filter and sort for the datasets catalog grid.
// Replaces the legacy jQuery + Isotope implementation with vanilla JS.
export default class extends Controller {
  static targets = ["grid", "noFilters", "showAllBar", "filteredCount",
                     "filterPanel", "sortPanel", "sourceSelect", "resetSort", "noResults"]

  connect() {
    this.sourceFilter = ""
    this.frequencyFilter = ""
    this.items = [...this.gridTarget.querySelectorAll(".grid-item")]
    this.originalOrder = [...this.items]
  }

  togglePanel(event) {
    event.preventDefault()
    const panel = event.currentTarget.dataset.panel
    if (panel === "filter") {
      const visible = this.filterPanelTarget.style.display !== "none"
      this.filterPanelTarget.style.display = visible ? "none" : "block"
      this.sortPanelTarget.style.display = "none"
    } else {
      const visible = this.sortPanelTarget.style.display !== "none"
      this.sortPanelTarget.style.display = visible ? "none" : "block"
      this.filterPanelTarget.style.display = "none"
    }
  }

  filterBySource() {
    this.sourceFilter = this.sourceSelectTarget.value
    this.applyFilters()
  }

  filterByFrequency(event) {
    const btn = event.currentTarget
    btn.parentElement.querySelectorAll(".btn-filter").forEach(b => b.classList.remove("is-checked"))
    btn.classList.add("is-checked")
    this.frequencyFilter = btn.dataset.frequency
    this.applyFilters()
  }

  sortByDate(event) {
    const direction = event.currentTarget.dataset.direction
    event.currentTarget.parentElement.querySelectorAll(".btn-sort").forEach(b => b.classList.remove("is-checked"))
    event.currentTarget.classList.add("is-checked")
    this.resetSortTarget.style.display = "inline"

    const sorted = [...this.items].sort((a, b) => {
      const da = new Date(a.dataset.date)
      const db = new Date(b.dataset.date)
      return direction === "asc" ? da - db : db - da
    })

    sorted.forEach(item => this.gridTarget.appendChild(item))
  }

  resetSort(event) {
    event.preventDefault()
    this.originalOrder.forEach(item => this.gridTarget.appendChild(item))
    this.resetSortTarget.style.display = "none"
    this.sortPanelTarget.querySelectorAll(".btn-sort").forEach(b => b.classList.remove("is-checked"))
  }

  showAll(event) {
    event.preventDefault()
    this.sourceFilter = ""
    this.frequencyFilter = ""
    this.sourceSelectTarget.value = ""
    this.element.querySelectorAll(".btn-filter").forEach(b => b.classList.remove("is-checked"))
    this.applyFilters()
  }

  applyFilters() {
    let visibleCount = 0

    this.items.forEach(item => {
      const matchSource = !this.sourceFilter || item.dataset.source === this.sourceFilter
      const matchFreq = !this.frequencyFilter || item.dataset.frequency === this.frequencyFilter
      const visible = matchSource && matchFreq
      item.style.display = visible ? "" : "none"
      if (visible) visibleCount++
    })

    if (visibleCount === this.items.length) {
      this.showAllBarTarget.style.display = "none"
      this.noFiltersTarget.style.display = ""
    } else {
      this.showAllBarTarget.style.display = ""
      this.noFiltersTarget.style.display = "none"
      this.filteredCountTarget.textContent = visibleCount
    }

    this.noResultsTarget.style.display = visibleCount === 0 ? "" : "none"
  }
}
