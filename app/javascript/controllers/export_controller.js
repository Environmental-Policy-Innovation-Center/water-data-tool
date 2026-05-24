import { Controller } from "@hotwired/stimulus"
import * as FilterState from "filter_state"
import * as SelectionState from "selection_state"

export default class extends Controller {
  static targets = ["format"]
  static values = { url: String }

  download(event) {
    event.preventDefault()
    const format = this.formatTargets.find(el => el.checked)?.value || "csv"
    const ids = SelectionState.getIds()
    const params = ids.length > 0 ? new URLSearchParams() : FilterState.toUrlParams()
    if (format !== "csv") params.set("file_format", format)
    ids.forEach(id => params.append("pwsids[]", id))

    window.location.href = `${this.urlValue}?${params}`
  }
}
