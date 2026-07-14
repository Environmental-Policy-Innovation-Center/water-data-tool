import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    text: String,
    html: { type: Boolean, default: false },
    interactive: { type: Boolean, default: false }
  }

  show() {
    this.#cancelHide()
    if (this.#tip && this.#shownText === this.textValue) return
    this.#removeTip()
    this.#tip = document.createElement("div")
    this.#tip.setAttribute("role", "tooltip")

    if (this.htmlValue) {
      this.#tip.innerHTML = this.textValue
      this.#tip.querySelectorAll("a").forEach(a => {
        a.target = "_blank"
        a.rel = "noopener noreferrer"
      })
    } else {
      this.#tip.textContent = this.textValue
    }

    this.#tip.className = "fixed w-64 whitespace-normal px-3 py-2 text-base leading-snug text-neutral-800 bg-neutral-200 rounded-xl shadow-md z-[9999] invisible"

    if (this.interactiveValue) {
      this.#tip.addEventListener("mouseenter", () => this.#cancelHide())
      this.#tip.addEventListener("mouseleave", () => this.hide())
    } else {
      this.#tip.classList.add("pointer-events-none")
    }

    document.body.appendChild(this.#tip)
    this.#position()
    this.#tip.classList.remove("invisible")
    this.#shownText = this.textValue
  }

  hide() {
    if (this.interactiveValue) {
      this.#hideTimer = setTimeout(() => this.#removeTip(), 200)
    } else {
      this.#removeTip()
    }
  }

  #tip = null
  #hideTimer = null
  #shownText = null

  #cancelHide() {
    clearTimeout(this.#hideTimer)
    this.#hideTimer = null
  }

  #removeTip() {
    this.#tip?.remove()
    this.#tip = null
    this.#shownText = null
  }

  #position() {
    const anchor = this.element.getBoundingClientRect()
    const tip = this.#tip.getBoundingClientRect()
    const gap = 6

    const top = Math.max(gap, anchor.top - tip.height - gap)
    const left = Math.max(gap, Math.min(window.innerWidth - tip.width - gap, anchor.right - tip.width))

    this.#tip.style.top = `${top}px`
    this.#tip.style.left = `${left}px`
  }
}
