import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "dropdown"]

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

  #open() {
    const rect = this.buttonTarget.getBoundingClientRect()
    const dropdown = this.dropdownTarget
    dropdown.style.top = `${rect.bottom + 8}px`
    dropdown.style.right = "8px" // overhangs container-table's right-4 edge by the same 8px gap
    dropdown.classList.remove("hidden")
    dropdown.classList.add("flex")
    this.buttonTarget.setAttribute("aria-expanded", "true")
  }

  #close() {
    this.dropdownTarget.classList.remove("flex")
    this.dropdownTarget.classList.add("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }
}
