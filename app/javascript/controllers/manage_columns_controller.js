import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "dropdown", "form", "colsInput"]

  #outsideClick = (e) => {
    if (!this.element.contains(e.target)) this.#close()
  }

  #onKeydown = (e) => {
    if (e.key === "Escape") { this.#close(); this.buttonTarget.focus() }
  }

  connect() {
    document.addEventListener("click", this.#outsideClick)
    document.addEventListener("keydown", this.#onKeydown)
  }

  disconnect() {
    document.removeEventListener("click", this.#outsideClick)
    document.removeEventListener("keydown", this.#onKeydown)
  }

  toggle() {
    this.dropdownTarget.classList.contains("hidden") ? this.#open() : this.#close()
  }

  toggleCategoryCollapse(event) {
    const btn = event.currentTarget
    const expanded = btn.getAttribute("aria-expanded") === "true"
    this.#setCategoryExpanded(btn.dataset.categoryKey, !expanded)
  }

  toggleCategory(event) {
    const { category } = event.target.dataset
    this.formTarget.querySelectorAll(`input[data-col-key][data-category="${category}"]`)
      .forEach(cb => { cb.checked = event.target.checked })
    this.#setCategoryExpanded(category, event.target.checked)
  }

  syncCategoryState(event) {
    this.#updateCategoryState(event.target.dataset.category)
  }

  serializeCols() {
    const allBoxes = this.formTarget.querySelectorAll('input[type="checkbox"][data-col-key]')
    const checkedKeys = Array.from(allBoxes).filter(cb => cb.checked).map(cb => cb.dataset.colKey)
    // null = all checked (omit param = default); "" = none checked (pinned only); "a,b" = explicit selection
    const keys = checkedKeys.length === allBoxes.length ? null : checkedKeys.join(",")
    this.colsInputTarget.disabled = keys === null
    this.colsInputTarget.value = keys ?? ""
    this.#updateUrl(keys)
    this.#close()
  }

  selectAllColumns()   { this.#setAllColumns(true) }
  deselectAllColumns() { this.#setAllColumns(false) }

  reset() {
    this.formTarget.querySelectorAll('input[type="checkbox"][data-col-key]').forEach(cb => cb.checked = true)
    this.#collapseAllCategories()
    this.formTarget.requestSubmit()
  }

  #collapseAllCategories() {
    this.formTarget.querySelectorAll('button[aria-controls^="cat-body-"]').forEach(btn => {
      this.#setCategoryExpanded(btn.dataset.categoryKey, false)
    })
  }

  #setAllColumns(checked) {
    const categoryKeys = new Set()
    this.formTarget.querySelectorAll('input[type="checkbox"][data-col-key]').forEach(cb => {
      cb.checked = checked
      if (cb.dataset.category) categoryKeys.add(cb.dataset.category)
    })
    categoryKeys.forEach(key => this.#updateCategoryState(key))
  }

  #updateUrl(keys) {
    const url = new URL(window.location)
    keys === null ? url.searchParams.delete("cols") : url.searchParams.set("cols", keys)
    history.replaceState({}, "", url)
  }

  #open() {
    this.#syncCheckboxesFromUrl()
    const rect = this.buttonTarget.getBoundingClientRect()
    const footer = document.querySelector('[aria-label="Table navigation"]')
    const footerTop = footer?.getBoundingClientRect().top ?? window.innerHeight
    const gap = 8
    const dropdown = this.dropdownTarget
    dropdown.style.top = `${rect.bottom + gap}px`
    dropdown.style.right = `${gap}px`
    dropdown.style.maxHeight = `${footerTop - rect.bottom - gap * 2}px`
    dropdown.classList.remove("hidden")
    dropdown.classList.add("flex")
    this.buttonTarget.setAttribute("aria-expanded", "true")
  }

  #syncCheckboxesFromUrl() {
    const cols = new URLSearchParams(window.location.search).get("cols")
    // null = param absent (show all); "" = explicitly empty (pinned only); "a,b" = specific keys
    const visibleKeys = cols !== null ? new Set(cols.split(",").filter(Boolean)) : null
    const categoryKeys = new Set()
    this.formTarget.querySelectorAll('input[type="checkbox"][data-col-key]').forEach(cb => {
      cb.checked = visibleKeys === null || visibleKeys.has(cb.dataset.colKey)
      if (cb.dataset.category) categoryKeys.add(cb.dataset.category)
    })
    categoryKeys.forEach(key => this.#updateCategoryState(key))
  }

  #setCategoryExpanded(categoryKey, expanded) {
    const btn = this.formTarget.querySelector(`button[aria-controls="cat-body-${categoryKey}"]`)
    if (!btn) return
    btn.setAttribute("aria-expanded", String(expanded))
    document.getElementById(`cat-body-${categoryKey}`)?.classList.toggle("hidden", !expanded)
    btn.querySelector("svg")?.classList.toggle("-rotate-90", !expanded)
  }

  #updateCategoryState(categoryKey) {
    const header = this.formTarget.querySelector(`input[data-category="${categoryKey}"]:not([data-col-key])`)
    if (!header) return
    const children = Array.from(this.formTarget.querySelectorAll(`input[data-col-key][data-category="${categoryKey}"]`))
    const checkedCount = children.filter(cb => cb.checked).length
    header.checked = checkedCount === children.length
    header.indeterminate = checkedCount > 0 && checkedCount < children.length
  }

  #close() {
    this.dropdownTarget.classList.remove("flex")
    this.dropdownTarget.classList.add("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }
}
