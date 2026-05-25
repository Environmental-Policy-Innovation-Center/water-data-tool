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

  serializeCols() {
    const allBoxes = this.formTarget.querySelectorAll('input[type="checkbox"][data-col-key]')
    const checkedKeys = Array.from(allBoxes).filter(cb => cb.checked).map(cb => cb.dataset.colKey)
    // All checked = default state; omit the cols param rather than listing every key
    const keys = checkedKeys.length === allBoxes.length ? "" : checkedKeys.join(",")
    this.colsInputTarget.value = keys
    this.#updateUrl(keys)
    this.#close()
  }

  reset() {
    this.formTarget.querySelectorAll('input[type="checkbox"][data-col-key]').forEach(cb => cb.checked = true)
    this.formTarget.requestSubmit()
  }

  #updateUrl(keys) {
    const url = new URL(window.location)
    keys ? url.searchParams.set("cols", keys) : url.searchParams.delete("cols")
    history.replaceState({}, "", url)
  }

  #open() {
    this.#syncCheckboxesFromUrl()
    const rect = this.buttonTarget.getBoundingClientRect()
    const dropdown = this.dropdownTarget
    dropdown.style.top = `${rect.bottom + 8}px`
    dropdown.style.right = "8px" // overhangs container-table's right-4 edge by the same 8px gap
    dropdown.classList.remove("hidden")
    dropdown.classList.add("flex")
    this.buttonTarget.setAttribute("aria-expanded", "true")
  }

  #syncCheckboxesFromUrl() {
    const cols = new URLSearchParams(window.location.search).get("cols")
    const visibleKeys = cols ? new Set(cols.split(",")) : null
    this.formTarget.querySelectorAll('input[type="checkbox"][data-col-key]').forEach(cb => {
      cb.checked = visibleKeys === null || visibleKeys.has(cb.dataset.colKey)
    })
  }

  #close() {
    this.dropdownTarget.classList.remove("flex")
    this.dropdownTarget.classList.add("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }
}
