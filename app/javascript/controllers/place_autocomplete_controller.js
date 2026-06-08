import { Controller } from "@hotwired/stimulus"

// Typeahead search for census places — fetches from /places/search,
// renders a dropdown, and sets a hidden place_geoid field on selection.
export default class extends Controller {
  static targets = ["input", "results", "geoid", "optionTemplate"]

  connect() {
    this._debounce = null
    this._pulseTimeout = null
    this._activeIndex = -1
    this._selectedLabel = this.geoidTarget.value ? this.inputTarget.value : ""

    // Keep input focused while clicking a result so blur does not tear down the list first
    this.resultsTarget.addEventListener("mousedown", (event) => event.preventDefault())

    this._onFiltersChanged = () => this.#reconcileInput()
    document.addEventListener("filters:changed", this._onFiltersChanged)
  }

  disconnect() {
    clearTimeout(this._debounce)
    clearTimeout(this._pulseTimeout)
    document.removeEventListener("filters:changed", this._onFiltersChanged)
  }

  search() {
    clearTimeout(this._debounce)
    const q = this.inputTarget.value.trim()

    if (q.length < 2) {
      this.#hideResults()
      this.geoidTarget.value = ""
      this._selectedLabel = ""
      return
    }

    if (this.inputTarget.value !== this._selectedLabel) {
      this.geoidTarget.value = ""
    }

    this._debounce = setTimeout(() => this.#fetch(q), 250)
  }

  keydown(event) {
    if (!this.#resultsOpen()) return

    const buttons = this.#optionButtons()
    if (buttons.length === 0) return

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.#setActiveOption(Math.min(this._activeIndex + 1, buttons.length - 1))
        break
      case "ArrowUp":
        event.preventDefault()
        this.#setActiveOption(Math.max(this._activeIndex - 1, -1))
        break
      case "Enter":
        if (this._activeIndex >= 0) {
          event.preventDefault()
          buttons[this._activeIndex].click()
        }
        break
      case "Escape":
        event.preventDefault()
        this.#dismiss()
        break
    }
  }

  select(event) {
    event.preventDefault()
    event.stopPropagation()
    const geoid = event.currentTarget.dataset.geoid
    const name = event.currentTarget.dataset.name

    this.geoidTarget.value = geoid
    this.inputTarget.value = name
    this._selectedLabel = name
    this.#hideResults()
  }

  focusOut() {
    setTimeout(() => {
      if (!this.element.contains(document.activeElement)) this.#dismiss()
    }, 0)
  }

  async #fetch(q) {
    try {
      const resp = await fetch(`/places/search?q=${encodeURIComponent(q)}`)
      if (!resp.ok) { this.#hideResults(); return }
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
      const label = `${p.name}, ${p.stusps}`
      const row = this.optionTemplateTarget.content.cloneNode(true)
      const btn = row.querySelector('[role="option"]')

      btn.id = `place-search-option-${p.geoid}`
      btn.dataset.geoid = p.geoid
      btn.dataset.name = label
      btn.textContent = label
      this.resultsTarget.appendChild(row)
    })
    this.resultsTarget.classList.remove("hidden")
    this.inputTarget.setAttribute("aria-expanded", "true")
    this.#setActiveOption(-1)
  }

  #dismiss() {
    this.#reconcileInput()
    this.#hideResults()
  }

  #reconcileInput() {
    if (this.geoidTarget.value) return

    this.inputTarget.value = ""
    this._selectedLabel = ""
  }

  #hideResults() {
    if (this.resultsTarget.classList.contains("hidden")) return
    this.resultsTarget.classList.add("hidden")
    this.resultsTarget.innerHTML = ""
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.inputTarget.removeAttribute("aria-activedescendant")
    this._activeIndex = -1
  }

  #resultsOpen() {
    return !this.resultsTarget.classList.contains("hidden")
  }

  #optionButtons() {
    return [...this.resultsTarget.querySelectorAll('[role="option"]')]
  }

  #setActiveOption(index) {
    const wasInList = this._activeIndex >= 0
    this._activeIndex = index
    const buttons = this.#optionButtons()

    buttons.forEach((btn, i) => {
      const active = i === index
      btn.setAttribute("aria-selected", active ? "true" : "false")
    })

    if (index >= 0) {
      this.inputTarget.setAttribute("aria-activedescendant", buttons[index].id)
      this.#scrollOptionIntoView(buttons[index])
    } else {
      this.inputTarget.removeAttribute("aria-activedescendant")
      if (wasInList) this.#pulseInput()
    }
  }

  #pulseInput() {
    clearTimeout(this._pulseTimeout)
    this.inputTarget.setAttribute("data-pulse", "")
    this._pulseTimeout = window.setTimeout(() => {
      this.inputTarget.removeAttribute("data-pulse")
      this._pulseTimeout = null
    }, 200)
  }

  #scrollOptionIntoView(button) {
    const list = this.resultsTarget
    const listRect = list.getBoundingClientRect()
    const btnRect = button.getBoundingClientRect()

    if (btnRect.bottom > listRect.bottom) {
      list.scrollTop += btnRect.bottom - listRect.bottom
    } else if (btnRect.top < listRect.top) {
      list.scrollTop -= listRect.top - btnRect.top
    }
  }
}
