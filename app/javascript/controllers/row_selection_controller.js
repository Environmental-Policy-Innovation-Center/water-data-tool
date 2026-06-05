import { Controller } from "@hotwired/stimulus"
import * as SelectionState from "selection_state"

export default class extends Controller {
  static targets = ["row", "countBadge", "totalCount", "exportButton"]

  #syncPending = false
  #totalCount = 0

  // Captures the server-rendered total record count whenever the Turbo Frame reloads.
  totalCountTargetConnected(element) {
    this.#totalCount = parseInt(element.dataset.count, 10) || 0
    this.#updateBadge()
  }

  // Fires for each row checkbox as it enters the DOM, including after Turbo frame reloads.
  // Batched via microtask to avoid redundant badge updates when all rows connect at once.
  rowTargetConnected(element) {
    element.checked = SelectionState.has(element.value)
    this.#scheduleSyncBadge()
  }

  rowTargetDisconnected() {
    this.#scheduleSyncBadge()
  }

  #scheduleSyncBadge() {
    if (this.#syncPending) return
    this.#syncPending = true
    queueMicrotask(() => {
      this.#syncPending = false
      this.#updateBadge()
    })
  }

  toggle(event) {
    SelectionState.toggle(event.target.value)
    this.#updateBadge()
  }

  selectAll() {
    SelectionState.selectAll()
    this.rowTargets.forEach(c => { c.checked = true })
    this.#updateBadge()
  }

  deselectAll() {
    SelectionState.deselectAll()
    this.rowTargets.forEach(c => { c.checked = false })
    this.#updateBadge()
  }

  #updateBadge() {
    if (!this.hasCountBadgeTarget) return

    let text = null

    if (SelectionState.isAllChecked()) {
      text = "All"
    } else if (SelectionState.isAllMode()) {
      // All mode with some exclusions — show total minus excluded
      const n = this.#totalCount - SelectionState.excludedCount()
      if (n > 0) text = n.toLocaleString()
    } else {
      // None mode — always show count (including 0) to signal nothing is selected
      text = SelectionState.count().toLocaleString()
    }

    if (text) {
      this.countBadgeTarget.textContent = text
      this.countBadgeTarget.classList.remove("hidden")
    } else {
      this.countBadgeTarget.classList.add("hidden")
    }

    this.#updateExportButton()
  }

  #updateExportButton() {
    if (!this.hasExportButtonTarget) return

    const empty = !SelectionState.isAllMode() && SelectionState.count() === 0
    const btn = this.exportButtonTarget

    btn.classList.toggle("bg-[#67a25e]", !empty)
    btn.classList.toggle("bg-neutral-400", empty)
    btn.classList.toggle("cursor-not-allowed", empty)
    btn.setAttribute("aria-disabled", String(empty))

    if (empty) {
      btn.setAttribute("title", "Select at least one row to export")
    } else {
      btn.removeAttribute("title")
    }
  }
}
