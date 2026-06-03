import { Controller } from "@hotwired/stimulus"

// Map overlay: print and close (X). Standalone report layout: print only (back-to-map is link_to "/").
export default class extends Controller {
  static targets = ["overlay", "frame"]

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
