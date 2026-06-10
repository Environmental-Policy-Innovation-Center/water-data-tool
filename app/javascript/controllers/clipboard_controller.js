import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["copy", "check"]
  static values = { text: String }

  copy() {
    navigator.clipboard.writeText(this.textValue)
      .then(() => {
        this.copyTarget.classList.add("hidden")
        this.checkTarget.classList.remove("hidden")
        setTimeout(() => {
          this.copyTarget.classList.remove("hidden")
          this.checkTarget.classList.add("hidden")
        }, 2000)
      })
      .catch(() => { console.warn("Clipboard write failed") })
  }
}
