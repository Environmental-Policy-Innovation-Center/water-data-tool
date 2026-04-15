import { Controller } from "@hotwired/stimulus"

// Manages the PWS detail panel — close button clears the panel and
// removes the map highlight.
export default class extends Controller {
  static targets = ["frame"]

  close() {
    // Clear the Turbo Frame content
    const frame = this.hasFrameTarget
      ? this.frameTarget
      : document.getElementById("detail-panel")

    if (frame) {
      frame.innerHTML = ""
      frame.removeAttribute("src")
    }
  }
}
