import { Controller } from "@hotwired/stimulus"

// Typeahead search for census places — fetches from /places/search,
// renders a dropdown, and sets a hidden place_geoid field on selection.
export default class extends Controller {
  static targets = ["input", "results", "geoid"]

  connect() {
    this._debounce = null
    this._mouseInResults = false

    // Track mouse presence in results so blur doesn't close before selection
    this.resultsTarget.addEventListener("mousedown", () => { this._mouseInResults = true })
    this.resultsTarget.addEventListener("mouseup", () => { this._mouseInResults = false })
  }

  search() {
    clearTimeout(this._debounce)
    const q = this.inputTarget.value.trim()

    if (q.length < 2) {
      this.#hideResults()
      this.geoidTarget.value = ""
      return
    }

    this._debounce = setTimeout(() => this.#fetch(q), 250)
  }

  select(event) {
    event.preventDefault()
    event.stopPropagation()
    const geoid = event.currentTarget.dataset.geoid
    const name = event.currentTarget.dataset.name

    this.geoidTarget.value = geoid
    this.inputTarget.value = name
    this._mouseInResults = false
    this.#hideResults()
  }

  blur() {
    if (!this._mouseInResults) this.#hideResults()
  }

  async #fetch(q) {
    try {
      const resp = await fetch(`/places/search?q=${encodeURIComponent(q)}`)
      const places = await resp.json()
      this.#render(places)
    } catch {
      this.#hideResults()
    }
  }

  #render(places) {
    if (places.length === 0) {
      this.#hideResults()
      return
    }

    this.resultsTarget.innerHTML = ""
    places.forEach(p => {
      const li = document.createElement("li")
      const a = document.createElement("a")
      a.href = "javascript:void(0);"
      a.dataset.action = "click->place-autocomplete#select"
      a.dataset.geoid = p.geoid
      a.dataset.name = `${p.name}, ${p.stusps}`
      a.textContent = `${p.name}, ${p.stusps}`
      li.appendChild(a)
      this.resultsTarget.appendChild(li)
    })
    this.resultsTarget.style.display = "block"
  }

  #hideResults() {
    this.resultsTarget.style.display = "none"
    this.resultsTarget.innerHTML = ""
  }
}
