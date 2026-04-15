import { Controller } from "@hotwired/stimulus"

// Toggles the full-page report overlay visibility and populates
// the header fields from the loaded report content.
export default class extends Controller {
  static targets = ["overlay", "frame", "utilityName", "systemId", "state"]

  connect() {
    if (this.hasFrameTarget) {
      this.frameTarget.addEventListener("turbo:frame-load", () => this.#populateHeader())
    }
  }

  show() {
    if (this.hasOverlayTarget) this.overlayTarget.classList.remove("hidden")
  }

  close() {
    if (this.hasOverlayTarget) this.overlayTarget.classList.add("hidden")
  }

  #populateHeader() {
    const name = this.frameTarget.querySelector("[data-report-field='name']")
    const id = this.frameTarget.querySelector("[data-report-field='id']")
    const state = this.frameTarget.querySelector("[data-report-field='state']")

    if (this.hasUtilityNameTarget && name) this.utilityNameTarget.textContent = name.textContent
    if (this.hasSystemIdTarget && id) this.systemIdTarget.textContent = id.textContent
    if (this.hasStateTarget && state) this.stateTarget.textContent = state.textContent
  }
}
