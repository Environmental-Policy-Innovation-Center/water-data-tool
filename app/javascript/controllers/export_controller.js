import { Controller } from "@hotwired/stimulus"
import * as FilterState from "filter_state"

export default class extends Controller {
  static targets = ["format"]

  download(event) {
    event.preventDefault()
    const format = this.formatTargets.find(el => el.checked)?.value || "csv"
    const params = FilterState.toUrlParams()
    if (format !== "csv") params.set("file_format", format)
    window.location.href = `/public_water_systems/export?${params}`
  }
}
