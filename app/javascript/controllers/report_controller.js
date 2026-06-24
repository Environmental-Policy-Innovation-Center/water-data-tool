import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "frame"]

  back(event) {
    if (history.length > 1) {
      history.back()
    } else {
      window.location.href = event.currentTarget.dataset.fallbackUrl || "/"
    }
  }

  close() {
    if (this.hasOverlayTarget) this.overlayTarget.classList.add("hidden")
    if (this.hasFrameTarget) {
      this.frameTarget.removeAttribute("src")
      this.frameTarget.innerHTML = ""
    }
  }

  print() {
    window.print()
  }
}
