import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"
import { encodeState, decodeState, colsFromUrl } from "url_state_codec"

export default class extends Controller {
  static targets = ["button", "dropdown", "form", "columnList", "defaultTemplate"]

  #outsideClick = (e) => {
    if (!this.element.contains(e.target)) this.#close()
  }

  #onKeydown = (e) => {
    if (e.key === "Escape") { this.#close(); this.buttonTarget.focus() }
  }

  #onFormChange = () => this.#syncToggleAllLabel()

  #sortables = []
  #orderCustomized = false

  connect() {
    document.addEventListener("click", this.#outsideClick)
    document.addEventListener("keydown", this.#onKeydown)
    this.formTarget.addEventListener("change", this.#onFormChange)
    this.#initSortables()
  }

  disconnect() {
    document.removeEventListener("click", this.#outsideClick)
    document.removeEventListener("keydown", this.#onKeydown)
    this.formTarget.removeEventListener("change", this.#onFormChange)
    this.#destroySortables()
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
    this.#updateCategoryState(category)
    this.#syncToggleAllLabel()
  }

  syncCategoryState(event) {
    this.#updateCategoryState(event.target.dataset.category)
  }

  serializeCols(event) {
    event.preventDefault()
    const keys = this.#colKeysForSubmit()
    if (keys === colsFromUrl()) { this.#close(); return }
    this.#applyToTable(keys)
    this.#close()
  }

  toggleAllColumns() {
    const allBoxes = this.formTarget.querySelectorAll('input[type="checkbox"][data-col-key]')
    const allChecked = Array.from(allBoxes).every(cb => cb.checked)
    this.#setAllColumns(!allChecked)
    this.#syncToggleAllLabel()
  }

  reset() {
    this.#orderCustomized = false
    this.#restoreDefaultDomOrder()
    this.#setAllColumns(true)
    this.#collapseAllCategories()
    this.#syncToggleAllLabel()
    this.#close()
    if (colsFromUrl() !== null) {
      this.#applyToTable(null)
    }
  }

  #initSortables() {
    const options = {
      handle: ".drag-handle",
      animation: 150,
      ghostClass: "opacity-40",
      onEnd: (event) => this.#onReorder(event)
    }

    if (this.hasColumnListTarget) {
      this.#sortables.push(new Sortable(this.columnListTarget, {
        ...options,
        draggable: "> li"
      }))
    }

    // Turbo frame updates that replace the panel DOM require calling #initSortables again.
    this.formTarget.querySelectorAll('ul[id^="cat-body-"]').forEach((list) => {
      this.#sortables.push(new Sortable(list, options))
    })
  }

  #destroySortables() {
    this.#sortables.forEach((sortable) => sortable.destroy())
    this.#sortables = []
  }

  #onReorder(event) {
    // Cross-category drag is blocked (no Sortable group option), so same-index = no move.
    if (event.newIndex === event.oldIndex) return
    this.#orderCustomized = true
  }

  #restoreDefaultDomOrder() {
    if (!this.hasColumnListTarget || !this.hasDefaultTemplateTarget) return
    this.#destroySortables()
    this.columnListTarget.innerHTML = ""
    this.columnListTarget.appendChild(this.defaultTemplateTarget.content.cloneNode(true))
    this.#initSortables()
  }

  #applyToTable(colsKeys) {
    this.#updateUrl(colsKeys)
    Turbo.visit(`/table${window.location.search}`, { frame: "data-table" })
  }

  #colKeysForSubmit() {
    const allCheckboxes = Array.from(this.formTarget.querySelectorAll('input[type="checkbox"][data-col-key]'))
    const allVisible = allCheckboxes.every((cb) => cb.checked)
    if (!this.#orderCustomized && allVisible) return null
    return allCheckboxes.map((cb) => cb.checked ? cb.dataset.colKey : `-${cb.dataset.colKey}`).join(",")
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
    const sp = url.searchParams
    const existingBlob = sp.get("encoded")
    let newBlob = null

    if (existingBlob) {
      const state = decodeState(existingBlob)
      if (keys === null) { delete state.cols } else { state.cols = keys }
      if (Object.keys(state).length > 0) {
        newBlob = encodeState(state)
        sp.set("encoded", newBlob)
      } else {
        sp.delete("encoded")
      }
    } else if (keys !== null) {
      newBlob = encodeState({ cols: keys })
      sp.set("encoded", newBlob)
    } else {
      sp.delete("encoded")
    }

    history.replaceState({}, "", url)
    return newBlob
  }

  #open() {
    const cols = colsFromUrl()
    this.#orderCustomized = cols !== null
    // Syncs checkboxes only; DOM list order reflects the last full page load, not URL changes since.
    this.#syncCheckboxesFromUrl(cols)
    this.#syncToggleAllLabel()
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

  #syncCheckboxesFromUrl(cols = colsFromUrl()) {
    const hiddenColKeys = cols === null ? null : this.#hiddenColKeysFromCols(cols)
    const categoryKeys = new Set()
    this.formTarget.querySelectorAll('input[type="checkbox"][data-col-key]').forEach(cb => {
      cb.checked = hiddenColKeys === null || !hiddenColKeys.has(cb.dataset.colKey)
      if (cb.dataset.category) categoryKeys.add(cb.dataset.category)
    })
    categoryKeys.forEach(key => this.#updateCategoryState(key))
  }

  #hiddenColKeysFromCols(cols) {
    return new Set(cols.split(",").filter(s => s.startsWith("-")).map(s => s.slice(1)))
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

  #syncToggleAllLabel() {
    const allBoxes = this.formTarget.querySelectorAll('input[type="checkbox"][data-col-key]')
    const allChecked = Array.from(allBoxes).every(cb => cb.checked)

    const label = document.getElementById("manage-columns-toggle-all-label")
    if (label) label.textContent = allChecked ? "Deselect all" : "Select all"

    document.getElementById("manage-columns-toggle-all-icon-on")?.classList.toggle("hidden", !allChecked)
    document.getElementById("manage-columns-toggle-all-icon-off")?.classList.toggle("hidden", allChecked)
  }

  #close() {
    this.dropdownTarget.classList.remove("flex")
    this.dropdownTarget.classList.add("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }
}
