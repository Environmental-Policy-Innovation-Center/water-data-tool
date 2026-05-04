import { Controller } from "@hotwired/stimulus"

// Subpixel tolerance when comparing sentinel bottom to the content box (layout noise).
const CLIP_EPSILON_PX = 2

// Toggles "show more" / "show less" when .dataset-card-body clips copy (see application.css).
// Uses a bottom sentinel + getBoundingClientRect instead of scrollHeight − clientHeight so we
// detect real clipping (including thin overflows) without a large arbitrary px threshold.
export default class extends Controller {
  static targets = ["content", "toggle", "sentinel"]

  connect() {
    this._destroyed = false
    this._resizeObserver = new ResizeObserver(() => this._scheduleUpdate())
    this._resizeObserver.observe(this.contentTarget)

    if (document.fonts?.ready) {
      document.fonts.ready.then(() => this._scheduleUpdate())
    }

    this._scheduleUpdate()
  }

  disconnect() {
    this._destroyed = true
    this._resizeObserver?.disconnect()
    if (this._rafId) cancelAnimationFrame(this._rafId)
  }

  _scheduleUpdate() {
    if (this._destroyed) return
    if (this._rafId) cancelAnimationFrame(this._rafId)
    this._rafId = requestAnimationFrame(() => {
      this._rafId = null
      this._updateToggleVisibility()
    })
  }

  _contentIsClipped() {
    const el = this.contentTarget
    if (this.hasSentinelTarget) {
      const cr = el.getBoundingClientRect()
      const sr = this.sentinelTarget.getBoundingClientRect()
      return sr.bottom > cr.bottom + CLIP_EPSILON_PX
    }
    return el.scrollHeight - el.clientHeight > CLIP_EPSILON_PX
  }

  _updateToggleVisibility() {
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

    const needsToggle = this._contentIsClipped()
    this.toggleTarget.hidden = !needsToggle
    if (needsToggle) {
      this.toggleTarget.textContent = "show more"
      this.toggleTarget.setAttribute("aria-expanded", "false")
    } else {
      this.toggleTarget.removeAttribute("aria-expanded")
    }
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
    this._scheduleUpdate()
  }

  collapse() {
    this.contentTarget.classList.add("dataset-card-body")
    this._scheduleUpdate()
  }
}
