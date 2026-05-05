import { Controller } from "@hotwired/stimulus"

// Subpixel tolerance when comparing sentinel bottom to the content box (layout noise).
const CLIP_EPSILON_PX = 2

// Uses a sentinel + getBoundingClientRect for clip detection instead of scrollHeight heuristics.
export default class extends Controller {
  static targets = ["content", "toggle", "sentinel"]

  #destroyed = false
  #resizeObserver = null
  #rafId = null

  connect() {
    this.#resizeObserver = new ResizeObserver(() => this.#scheduleUpdate())
    this.#resizeObserver.observe(this.contentTarget)

    if (document.fonts?.ready) {
      document.fonts.ready.then(() => this.#scheduleUpdate())
    }

    this.#scheduleUpdate()
  }

  disconnect() {
    this.#destroyed = true
    this.#resizeObserver?.disconnect()
    if (this.#rafId) cancelAnimationFrame(this.#rafId)
  }

  toggle() {
    if (this.contentTarget.classList.contains("dataset-card-body")) {
      this.expand()
    } else {
      this.collapse()
    }
  }

  expand() {
    this.contentTarget.classList.remove("dataset-card-body")
    this.#scheduleUpdate()
  }

  collapse() {
    this.contentTarget.classList.add("dataset-card-body")
    this.#scheduleUpdate()
  }

  #scheduleUpdate() {
    if (this.#destroyed) return
    if (this.#rafId) cancelAnimationFrame(this.#rafId)
    this.#rafId = requestAnimationFrame(() => {
      this.#rafId = null
      this.#updateToggleVisibility()
    })
  }

  #contentIsClipped() {
    const el = this.contentTarget
    if (this.hasSentinelTarget) {
      const cr = el.getBoundingClientRect()
      const sr = this.sentinelTarget.getBoundingClientRect()
      return sr.bottom > cr.bottom + CLIP_EPSILON_PX
    }
    return el.scrollHeight - el.clientHeight > CLIP_EPSILON_PX
  }

  #updateToggleVisibility() {
    if (!this.hasContentTarget || !this.hasToggleTarget) return

    const el = this.contentTarget
    const { width, height } = el.getBoundingClientRect()
    if (width === 0 && height === 0) {
      this.toggleTarget.hidden = true
      this.toggleTarget.removeAttribute("aria-expanded")
      return
    }

    const collapsed = el.classList.contains("dataset-card-body")
    if (!collapsed) {
      this.toggleTarget.hidden = false
      this.toggleTarget.textContent = "show less"
      this.toggleTarget.setAttribute("aria-expanded", "true")
      return
    }

    const needsToggle = this.#contentIsClipped()
    this.toggleTarget.hidden = !needsToggle
    if (needsToggle) {
      this.toggleTarget.textContent = "show more"
      this.toggleTarget.setAttribute("aria-expanded", "false")
    } else {
      this.toggleTarget.removeAttribute("aria-expanded")
    }
  }
}
