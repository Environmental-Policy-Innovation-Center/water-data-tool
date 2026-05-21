import { Controller } from "@hotwired/stimulus"
import * as SelectionState from "selection_state"

export default class extends Controller {
  static targets = ["selectAll", "row", "countBadge"]

  // Fires for each row checkbox as it enters the DOM, including after Turbo frame reloads.
  // This is how selection state persists across pagination without manual event listeners.
  rowTargetConnected(element) {
    element.checked = SelectionState.has(element.value)
    this.#syncSelectAll()
  }

  rowTargetDisconnected() {
    this.#syncSelectAll()
  }

  toggle(event) {
    SelectionState.toggle(event.target.value)
    this.#syncSelectAll()
  }

  toggleAll(event) {
    const ids = this.rowTargets.map(c => c.value)
    if (event.target.checked) {
      SelectionState.selectPage(ids)
      this.rowTargets.forEach(c => { c.checked = true })
    } else {
      SelectionState.deselectPage(ids)
      this.rowTargets.forEach(c => { c.checked = false })
    }
    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked = event.target.checked && ids.length > 0
      this.selectAllTarget.indeterminate = false
    }
    this.#updateBadge()
  }

  #syncSelectAll() {
    if (this.hasSelectAllTarget) {
      const rows = this.rowTargets
      const checkedCount = rows.filter(c => c.checked).length
      this.selectAllTarget.checked = rows.length > 0 && checkedCount === rows.length
      this.selectAllTarget.indeterminate = checkedCount > 0 && checkedCount < rows.length
    }
    this.#updateBadge()
  }

  #updateBadge() {
    if (!this.hasCountBadgeTarget) return
    const n = SelectionState.count()
    if (n > 0) {
      this.countBadgeTarget.textContent = n
      this.countBadgeTarget.classList.remove("hidden")
    } else {
      this.countBadgeTarget.classList.add("hidden")
    }
  }
}
