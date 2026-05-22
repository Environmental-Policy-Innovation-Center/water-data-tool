import { Controller } from "@hotwired/stimulus"
import * as FilterState from "filter_state"
import * as SelectionState from "selection_state"

export default class extends Controller {
  static targets = ["format"]
  static values = { url: String }

  download(event) {
    event.preventDefault()
    const format = this.formatTargets.find(el => el.checked)?.value || "csv"
    const params = FilterState.toUrlParams()
    if (format !== "csv") params.set("file_format", format)

    SelectionState.getIds().forEach(id => params.append("pwsids[]", id))

    window.location.href = `${this.urlValue}?${params}`
  }
}
