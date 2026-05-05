import { Controller } from "@hotwired/stimulus"

// Preserves horizontal scroll position across Turbo frame reloads to avoid a visible flash.

export default class extends Controller {
  connect() {
    this.element.addEventListener("turbo:before-frame-render", this.#preserveScroll)
  }

  disconnect() {
    this.element.removeEventListener("turbo:before-frame-render", this.#preserveScroll)
  }

  #preserveScroll = (event) => {
    const scroll = this.element.querySelector(".table-scroll")
    if (!scroll) return

    const savedLeft = scroll.scrollLeft
    const originalRender = event.detail.render

    event.detail.render = async (...args) => {
      await originalRender(...args)
      const newScroll = this.element.querySelector(".table-scroll")
      if (newScroll) newScroll.scrollLeft = savedLeft
    }
  }
}
