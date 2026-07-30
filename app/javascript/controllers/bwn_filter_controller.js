import { Controller } from "@hotwired/stimulus"
import * as FilterState from "filter_state"

export default class extends Controller {
  static values = {
    bwnStates: Array,
    tooltips: Object
  }

  static targets = ["checkbox", "label", "disabledText", "stateTooltip", "arrowButton"]

  #onFiltersChanged = () => this.#syncState()

  connect() {
    document.addEventListener("filters:changed", this.#onFiltersChanged)
    this.#syncState()
  }

  disconnect() {
    document.removeEventListener("filters:changed", this.#onFiltersChanged)
  }

  #syncState() {
    const stusps = FilterState.get().state
    const isBwnState = !!stusps && this.bwnStatesValue.includes(stusps)

    this.#syncCheckbox(isBwnState)
    this.#syncStateTooltip(isBwnState, stusps)
  }

  #syncCheckbox(isBwnState) {
    if (!this.hasCheckboxTarget) return
    const checkbox = this.checkboxTarget

    checkbox.disabled = !isBwnState
    if (this.hasLabelTarget) this.labelTarget.classList.toggle("text-[#888]", !isBwnState)
    if (this.hasDisabledTextTarget) this.disabledTextTarget.classList.toggle("hidden", isBwnState)
    if (this.hasArrowButtonTarget) this.arrowButtonTarget.classList.toggle("hidden", !isBwnState)

    // BWN-to-BWN leaves the checkbox as the user left it, same as any other range filter.
    if (!isBwnState) {
      if (checkbox.checked) checkbox.checked = false
      this.#hideSliderPanel()
    }
  }

  #syncStateTooltip(isBwnState, stusps) {
    if (!this.hasStateTooltipTarget) return
    const tip = this.stateTooltipTarget

    if (isBwnState && this.tooltipsValue[stusps]) {
      tip.dataset.tooltipTextValue = this.tooltipsValue[stusps]
      tip.dataset.tooltipHtmlValue = "true"
      tip.dataset.tooltipInteractiveValue = "true"
      tip.classList.remove("hidden")
      tip.classList.add("inline-flex")
    } else {
      tip.classList.remove("inline-flex")
      tip.classList.add("hidden")
      tip.dataset.tooltipTextValue = ""
      tip.dataset.tooltipHtmlValue = "false"
      tip.dataset.tooltipInteractiveValue = "false"
    }
  }

  #hideSliderPanel() {
    const panelId = this.checkboxTarget?.dataset?.panelId
    if (!panelId) return
    const filterEl = this.element.closest("[data-controller~='filter']")
    this.application.getControllerForElementAndIdentifier(filterEl, "filter")?.hideHistogramPanel(panelId)
  }
}
