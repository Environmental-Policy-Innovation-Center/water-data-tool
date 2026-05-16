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
    const btn = event.currentTarget
    const active = btn.dataset.panel
    const other = active === "filter" ? "sort" : "filter"

    const selfPanel = this[`${active}PanelTarget`]
    const otherPanel = this[`${other}PanelTarget`]
    const otherBtn = this.element.querySelector(`[data-panel='${other}']`)

    const nowVisible = selfPanel.style.display === "none"
    selfPanel.style.display = nowVisible ? "block" : "none"
    btn.setAttribute("aria-expanded", String(nowVisible))
    otherPanel.style.display = "none"
    if (otherBtn) otherBtn.setAttribute("aria-expanded", "false")
  }

  filterBySource() {
    this.sourceFilter = this.sourceSelectTarget.value
    this.applyFilters()
  }

  filterByFrequency(event) {
    const btn = event.currentTarget
    this.#clearButtonGroup(".btn-filter", btn.parentElement)
    btn.setAttribute("data-active", "true")
    btn.setAttribute("aria-pressed", "true")
    this.frequencyFilter = btn.dataset.frequency
    this.applyFilters()
  }

  sortByDate(event) {
    const btn = event.currentTarget
    this.#clearButtonGroup(".btn-sort", btn.parentElement)
    btn.setAttribute("data-active", "true")
    btn.setAttribute("aria-pressed", "true")
    this.resetSortTarget.style.display = "inline"

    const direction = btn.dataset.direction
    const sorted = [...this.items].sort((a, b) => {
      const da = new Date(a.dataset.date)
      const db = new Date(b.dataset.date)
      return direction === "asc" ? da - db : db - da
    })

    sorted.forEach(item => this.gridTarget.appendChild(item))
  }

  resetSort() {
    this.originalOrder.forEach(item => this.gridTarget.appendChild(item))
    this.resetSortTarget.style.display = "none"
    this.#clearButtonGroup(".btn-sort", this.sortPanelTarget)
  }

  showAll() {
    this.sourceFilter = ""
    this.frequencyFilter = ""
    this.sourceSelectTarget.value = ""
    this.#clearButtonGroup(".btn-filter")
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

  #clearButtonGroup(selector, container = this.element) {
    container.querySelectorAll(selector).forEach(b => {
      b.setAttribute("data-active", "false")
      b.setAttribute("aria-pressed", "false")
    })
  }
}
