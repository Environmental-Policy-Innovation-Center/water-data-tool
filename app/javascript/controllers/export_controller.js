import { Controller } from "@hotwired/stimulus"
import * as FilterState from "filter_state"
import * as SelectionState from "selection_state"

export default class extends Controller {
  static targets = ["format"]
  static values = { url: String }

  download(event) {
    event.preventDefault()
    const format = this.formatTargets.find(el => el.checked)?.value || "csv"

    const form = document.createElement("form")
    form.method = "post"
    form.action = this.urlValue

    const append = (name, value) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = name
      input.value = value
      form.appendChild(input)
    }

    const csrfToken = document.querySelector("meta[name=csrf-token]")?.content
    if (!csrfToken) { console.error("CSRF token not found"); return }
    append("authenticity_token", csrfToken)

    if (SelectionState.isAllChecked()) {
      // All rows selected — export everything matching the current filters
      for (const [key, value] of new URLSearchParams(FilterState.toUrlParams())) {
        append(key, value)
      }
    } else if (SelectionState.isAllMode()) {
      // All mode with some unchecked — export filter results minus the excluded IDs
      for (const [key, value] of new URLSearchParams(FilterState.toUrlParams())) {
        append(key, value)
      }
      SelectionState.getExcludedIds().forEach(id => append("exclude_pwsids[]", id))
    } else {
      // Explicit mode — export only the manually checked IDs
      const ids = SelectionState.getIds()
      if (ids.length === 0) return
      ids.forEach(id => append("pwsids[]", id))
    }

    if (format !== "csv") append("file_format", format)

    document.body.appendChild(form)
    form.submit()
    document.body.removeChild(form)
  }
}
