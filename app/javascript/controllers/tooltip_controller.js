import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String }

  show() {
    this.#tip = document.createElement("div")
    this.#tip.setAttribute("role", "tooltip")
    this.#tip.textContent = this.textValue
    // Invisible while we measure; fixed so it escapes any overflow:hidden ancestor
    this.#tip.className = "fixed w-64 whitespace-normal px-3 py-2 text-base leading-snug text-neutral-800 bg-neutral-200 rounded-xl shadow-md pointer-events-none z-[9999] invisible"
    document.body.appendChild(this.#tip)
    this.#position()
    this.#tip.classList.remove("invisible")
  }

  hide() {
    this.#tip?.remove()
    this.#tip = null
  }

  #tip = null

  #position() {
    const anchor = this.element.getBoundingClientRect()
    const tip = this.#tip.getBoundingClientRect()
    const gap = 6

    // Prefer above; clamp so it never goes off-screen
    const top = Math.max(gap, anchor.top - tip.height - gap)
    const left = Math.max(gap, Math.min(window.innerWidth - tip.width - gap, anchor.right - tip.width))

    this.#tip.style.top = `${top}px`
    this.#tip.style.left = `${left}px`
  }
}
