import { Controller } from "@hotwired/stimulus"
import * as SearchState from "search_state"
import { syncToUrl } from "url_sync"
import { searchFromUrl } from "url_state_codec"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this._debounce = null
    this._onResetAll = () => this.#clearSearch()
    document.addEventListener("filter:reset-all", this._onResetAll)

    const saved = searchFromUrl()
    if (saved) { SearchState.set(saved); this.inputTarget.value = saved }
  }

  disconnect() {
    clearTimeout(this._debounce)
    document.removeEventListener("filter:reset-all", this._onResetAll)
  }

  search() {
    clearTimeout(this._debounce)
    const term = this.inputTarget.value.trim()
    if (term.length < 2) {
      if (SearchState.get()) this.#applySearch(term)
      return
    }
    this._debounce = setTimeout(() => this.#applySearch(term), 300)
  }

  #applySearch(term) {
    if (term.length >= 2) { SearchState.set(term) } else { SearchState.clear() }
    syncToUrl()
    Turbo.visit(`/table${window.location.search}`, { frame: "data-table" })
  }

  #clearSearch() {
    this.inputTarget.value = ""
    SearchState.clear()
  }
}
