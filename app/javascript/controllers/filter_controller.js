import { Controller } from "@hotwired/stimulus"
import * as FilterState from "filter_state"
import { syncStatsFrame } from "stats_frame"
import * as SelectionState from "selection_state"
import { decodeState } from "url_state_codec"
import { syncToUrl } from "url_sync"

// Reads the data-filter-* contract emitted by the generated filter menus (config/filter_layout.yml ×
// config/fields.yml). Each control root carries data-filter-kind + data-filter-group; options carry
// data-filter-value/param. Adding or removing a filter is a config + ERB change only — no edit here.
// Menu open/close lives in filter_menu_controller. Responsive layout in filter_layout_controller.
export default class extends Controller {
  #tableLoaded = false

  // Syncs sort/direction from the server-rendered table state into the page URL after each frame load.
  // Reading from #table-query-state (server-rendered) is authoritative — it reflects what the server
  // actually received, not what we predicted would be fetched.
  #onTableFrameLoad = () => {
    const queryState = document.getElementById("table-query-state")
    if (!queryState) return

    const sort = queryState.dataset.sort || null
    const direction = queryState.dataset.direction || null

    const pageUrl = new URL(window.location)
    if (pageUrl.searchParams.get("sort") === sort && pageUrl.searchParams.get("direction") === direction) return

    if (sort) pageUrl.searchParams.set("sort", sort); else pageUrl.searchParams.delete("sort")
    if (direction) pageUrl.searchParams.set("direction", direction); else pageUrl.searchParams.delete("direction")
    history.replaceState({}, "", pageUrl)
  }

  connect() {
    document.addEventListener("table:show", this.#onTableShow)
    document.addEventListener("filter:layout-changed", this.#onLayoutChanged)
    document.getElementById("data-table")?.addEventListener("turbo:frame-load", this.#onTableFrameLoad)
    this.#restoreFromUrl()
    this.#updateBadges()
    this.#updateGeoTitle()
  }

  disconnect() {
    document.removeEventListener("table:show", this.#onTableShow)
    document.removeEventListener("filter:layout-changed", this.#onLayoutChanged)
    document.getElementById("data-table")?.removeEventListener("turbo:frame-load", this.#onTableFrameLoad)
  }

  apply(event) {
    event.preventDefault()
    document.dispatchEvent(new CustomEvent("filter:close-all"))
    FilterState.set({ ...this.#currentStateScope(), ...this.#collectFilters() })
    SelectionState.clear()
    syncToUrl()
    this.#updateBadges()
    this.#updateGeoTitle()
    document.dispatchEvent(new CustomEvent("filters:changed"))
    this.dispatch("applied")
    this.#reloadStatsFrame()
    this.#reloadTableFrame()
  }

  resetAll(event) {
    event.preventDefault()
    document.querySelectorAll(".filter-dropdown").forEach(menu => this.#resetMenu(menu))
    document.dispatchEvent(new CustomEvent("filter:reset-all"))
    this.apply(event)
  }

  toggleSelectAll(event) {
    const selectAll = event.currentTarget
    this.#multiselectOptions(this.#selectAllParam(selectAll)).forEach(cb => { cb.checked = selectAll.checked })
    this.#syncSelectAllLabel(selectAll)
  }

  syncSelectAll(event) {
    const param = event.currentTarget.dataset.filterParam
    const selectAll = document.getElementById(`${param}-select-all`)
    if (!selectAll) return
    selectAll.checked = this.#multiselectOptions(param).every(cb => cb.checked)
    this.#syncSelectAllLabel(selectAll)
  }

  togglePopSize(event) {
    event.preventDefault()
    event.currentTarget.classList.toggle("active")
  }

  toggleRateTierPanel(event) {
    const checkbox = event.currentTarget
    const root = checkbox.closest("[data-filter-kind='rate_tier']")
    const panel = document.getElementById(checkbox.dataset.panelId)
    if (!root || !panel) return

    if (!checkbox.checked) {
      root.querySelectorAll("button[data-filter-value]").forEach(btn => btn.classList.remove("active"))
      const noInfo = root.querySelector("input[data-filter-value='no_information']")
      if (noInfo) noInfo.checked = false
      this.#syncRateTierParent(root)
    } else {
      panel.classList.toggle("hidden")
      this.#setToggleArrow(checkbox.dataset.panelId, !panel.classList.contains("hidden"))
      checkbox.checked = false
    }
  }

  toggleRateTier(event) {
    event.preventDefault()
    event.currentTarget.classList.toggle("active")
    this.#syncRateTierParent(event.currentTarget.closest("[data-filter-kind='rate_tier']"))
  }

  onRateTierNoInfoChange(event) {
    this.#syncRateTierParent(event.currentTarget.closest("[data-filter-kind='rate_tier']"))
  }

  reset(event) {
    event.preventDefault()
    const menu = event.currentTarget.closest(".filter-dropdown")
    if (!menu) return
    this.#resetMenu(menu)
    this.apply(event)
  }

  // Gate for a standalone range (panel IS the slider) or a subcat parent (panel wraps child rows).
  // Checking seeds slider defaults so Apply always sends params for the active range(s).
  toggleSubcat(event) {
    const checkbox = event.currentTarget
    const panel = document.getElementById(checkbox.dataset.panelId)
    if (!panel) return

    const sliders = panel.dataset.sliderFieldValue
      ? [panel]
      : [...panel.querySelectorAll("[data-filter-kind='range'] [data-slider-field-value]")]

    if (checkbox.checked) {
      panel.classList.remove("hidden")
      this.#setToggleArrow(checkbox.dataset.panelId, true)
      this.#loadSlider(panel)
      panel.querySelectorAll("input[type='checkbox']").forEach(cb => { cb.checked = true })
      sliders.forEach(s => this.#populateSliderDefaults(s))
    } else {
      panel.querySelectorAll("input[type='checkbox']").forEach(cb => { cb.checked = false })
      sliders.forEach(s => this.#hideAndResetSlider(s))
    }
  }

  // Collapses/expands the subcat panel independently of the parent checkbox.
  toggleSubcatPanel(event) {
    event.preventDefault()
    const panelId = event.currentTarget.dataset.panelId
    const panel = panelId && document.getElementById(panelId)
    if (!panel) return

    const willShow = panel.classList.contains("hidden")
    panel.classList.toggle("hidden")
    this.#setToggleArrow(panelId, willShow)
    if (willShow) this.#loadSlider(panel)
  }

  // Keeps the parent checkbox in sync when child rows are individually toggled, and shows/hides
  // the changed row's histogram panel. Fires for every change bubbling out of the panel, so it
  // ignores anything that isn't a row gate checkbox (e.g. slider text inputs).
  syncParentFromSubcat(event) {
    if (event.target.type !== "checkbox") return
    const panel = event.currentTarget
    const rows = [...panel.querySelectorAll("[data-filter-kind='range']")]
    if (rows.length === 0) return

    const checkedCount = rows.filter(row => row.querySelector("input[type='checkbox']")?.checked).length
    const parentEl = this.element.querySelector(`input[type='checkbox'][data-panel-id='${CSS.escape(panel.id)}']`)
    if (parentEl) {
      parentEl.checked = checkedCount === rows.length
      parentEl.indeterminate = checkedCount > 0 && checkedCount < rows.length
    }

    const sliderPanel = event.target.closest("[data-filter-kind='range']")?.querySelector("[data-slider-field-value]")
    if (!sliderPanel) return
    if (event.target.checked) {
      sliderPanel.classList.remove("hidden")
      this.#populateSliderDefaults(sliderPanel)
    } else {
      this.#hideAndResetSlider(sliderPanel)
    }
  }

  #selectAllParam(selectAll) {
    return selectAll.id.replace(/-select-all$/, "")
  }

  #multiselectOptions(param) {
    return [...this.element.querySelectorAll(`input[data-filter-kind='multiselect'][data-filter-param='${CSS.escape(param)}']`)]
  }

  #syncSelectAllLabel(selectAll) {
    const label = document.querySelector(`label[for='${CSS.escape(selectAll.id)}']`)
    if (label) label.textContent = selectAll.checked ? "Deselect all" : "Select all"
  }

  #rateTierHasSelection(root) {
    return [...root.querySelectorAll("button[data-filter-value]")].some(btn => btn.classList.contains("active"))
      || Boolean(root.querySelector("input[data-filter-value='no_information']")?.checked)
  }

  #syncRateTierParent(root) {
    if (!root) return
    const parentCb = root.querySelector("input[data-panel-id]")
    if (parentCb) parentCb.checked = this.#rateTierHasSelection(root)
  }

  #hideAndResetSlider(sliderPanel) {
    if (!sliderPanel) return
    sliderPanel.classList.add("hidden")
    sliderPanel.querySelectorAll("input[type='hidden']").forEach(inp => { inp.value = "" })
    this.application.getControllerForElementAndIdentifier(sliderPanel, "slider")?.resetToFullRange()
  }

  #setToggleArrow(panelId, expanded) {
    const btn = this.element.querySelector(`button[data-panel-id="${panelId}"]`)
    if (!btn) return
    btn.setAttribute("aria-expanded", String(expanded))
    btn.querySelector("svg")?.classList.toggle("-rotate-90", !expanded)
  }

  #onLayoutChanged = () => this.#updateBadges()

  #onTableShow = () => {
    this.#tableLoaded = true
    this.#visitTableFrame()
  }

  #resetMenu(menu) {
    menu.querySelectorAll("input[type='radio']").forEach(r => { r.checked = r.hasAttribute("data-default") })
    menu.querySelectorAll("input[type='checkbox']").forEach(cb => {
      cb.checked = cb.classList.contains("default-checked")
      cb.indeterminate = false
    })
    menu.querySelectorAll(".select-all").forEach(sa => this.#syncSelectAllLabel(sa))
    menu.querySelectorAll("[data-subcat-panel]").forEach(panel => panel.classList.add("hidden"))
    menu.querySelectorAll("[data-slider-field-value]").forEach(sliderPanel => this.#hideAndResetSlider(sliderPanel))
    menu.querySelectorAll("button[data-panel-id]").forEach(btn => this.#setToggleArrow(btn.dataset.panelId, false))
    menu.querySelectorAll("select.min-select").forEach(s => { s.selectedIndex = 0 })
    menu.querySelectorAll("select.max-select").forEach(s => { s.selectedIndex = s.options.length - 1 })
    menu.querySelectorAll(".pop-size-box").forEach(b => b.classList.remove("active"))
    menu.querySelectorAll(".rate-tier-box").forEach(b => b.classList.remove("active"))
  }

  // Reads the live DOM into the URL param hash applied on Apply.
  #collectFilters() {
    const p = {}
    const seen = new Set()

    for (const el of this.element.querySelectorAll("[data-filter-kind]")) {
      switch (el.dataset.filterKind) {
        case "radio":
        case "bool": {
          // The default radio (e.g. "Both") carries an empty value — selecting it means "no filter".
          if (el.checked && el.dataset.filterValue) p[el.dataset.filterParam] = el.dataset.filterValue
          break
        }
        case "multiselect": {
          const param = el.dataset.filterParam
          if (seen.has(param)) break
          seen.add(param)
          const opts = this.#multiselectOptions(param)
          const checked = opts.filter(o => o.checked)
          if (checked.length > 0 && checked.length < opts.length) {
            p[param] = checked.map(o => o.dataset.filterValue)
          }
          break
        }
        case "pop_cat": {
          const btns = [...el.querySelectorAll("button[data-filter-value]")]
          const active = btns.filter(b => b.classList.contains("active"))
          if (active.length > 0 && active.length < btns.length) {
            p[el.dataset.filterParam] = active.map(b => b.dataset.filterValue)
          }
          break
        }
        case "rate_tier": {
          const selected = [...el.querySelectorAll("button[data-filter-value].active")].map(b => b.dataset.filterValue)
          if (el.querySelector("input[data-filter-value='no_information']")?.checked) selected.push("no_information")
          if (selected.length > 0) p[el.dataset.filterParam] = selected
          break
        }
        case "range": {
          if (!el.querySelector("input[type='checkbox']")?.checked) break
          const sliderPanel = el.querySelector("[data-slider-field-value]")
          const base = sliderPanel?.dataset.sliderFieldValue
          if (!base) break
          const minVal = sliderPanel.querySelector("[data-slider-target='minInput']")?.value
          const maxVal = sliderPanel.querySelector("[data-slider-target='maxInput']")?.value
          if (minVal) p[`${base}_min`] = minVal
          if (maxVal) p[`${base}_max`] = maxVal
          break
        }
        case "range_select": {
          const minVal = el.querySelector(".min-select")?.value
          const maxVal = el.querySelector(".max-select")?.value
          if (minVal && minVal !== el.dataset.filterMinSentinel) p[el.dataset.filterParamMin] = minVal
          if (maxVal && maxVal !== el.dataset.filterMaxSentinel) p[el.dataset.filterParamMax] = maxVal
          break
        }
      }
    }

    return p
  }

  #currentStateScope() {
    const current = FilterState.get()
    const stateScope = {}
    if (current.state) stateScope.state = current.state
    if (current.state_name) stateScope.state_name = current.state_name
    return stateScope
  }

  // The DOM is server-rendered with active filter state, so restore only re-seeds JS state and frames.
  #restoreFromUrl() {
    if (!window.location.search) return

    const sp = new URLSearchParams(window.location.search)
    const encoded = sp.get("encoded")
    if (!encoded) return

    const params = decodeState(encoded).filters ?? {}
    if (Object.keys(params).length === 0) return

    this.#loadVisibleSliders()
    FilterState.set(params)
    document.dispatchEvent(new CustomEvent("filters:changed"))
    this.#reloadStatsFrame()
    this.#reloadTableFrame()
  }

  // Per-menu active-filter counts from the applied state, derived from the data-filter-* contract.
  // Counting rules by kind: scalar (radio/bool/place) = 1; multiselect/pop_cat = selected count;
  // rate_tier = 1 parent + selected; range/range_select = 1; subcat parent = 1 when any child is set.
  #countsByGroup() {
    const p = FilterState.get()
    const counts = {}
    const seen = new Set()
    const add = (group, n) => { counts[group] = (counts[group] || 0) + n }
    const isSet = (key) => p[key] != null && p[key] !== ""
    const arrayLen = (key) => Array.isArray(p[key]) ? p[key].length : 0

    for (const el of this.element.querySelectorAll("[data-filter-kind]")) {
      const kind = el.dataset.filterKind
      const group = Number(el.dataset.filterGroup)
      switch (kind) {
        case "radio":
        case "place": {
          const key = `${kind}:${el.dataset.filterParam}`
          if (seen.has(key)) break
          seen.add(key)
          if (isSet(el.dataset.filterParam)) add(group, 1)
          break
        }
        case "bool": {
          if (isSet(el.dataset.filterParam)) add(group, 1)
          break
        }
        case "multiselect": {
          const param = el.dataset.filterParam
          if (seen.has(`${kind}:${param}`)) break
          seen.add(`${kind}:${param}`)
          add(group, arrayLen(param))
          break
        }
        case "pop_cat": {
          add(group, arrayLen(el.dataset.filterParam))
          break
        }
        case "rate_tier": {
          const items = arrayLen(el.dataset.filterParam)
          if (items > 0) add(group, 1 + items)
          break
        }
        case "range": {
          const base = el.querySelector("[data-slider-field-value]")?.dataset.sliderFieldValue
          if (base && (isSet(`${base}_min`) || isSet(`${base}_max`))) add(group, 1)
          break
        }
        case "range_select": {
          if (isSet(el.dataset.filterParamMin) || isSet(el.dataset.filterParamMax)) add(group, 1)
          break
        }
        case "subcat_parent": {
          const anyActive = [...el.querySelectorAll("[data-slider-field-value]")].some(s => {
            const base = s.dataset.sliderFieldValue
            return isSet(`${base}_min`) || isSet(`${base}_max`)
          })
          if (anyActive) add(group, 1)
          break
        }
      }
    }

    return counts
  }

  #updateBadges() {
    const counts = this.#countsByGroup()
    let moreCount = counts[10] || 0

    for (const group of [1, 2, 3, 4, 5]) {
      const li = document.querySelector(`.filter-${group}`)
      const count = counts[group] || 0
      if (li?.classList.contains("hidden")) {
        moreCount += count
      } else {
        this.#setBadge(document.querySelector(`.container-filter-count-menu-${group}`), count)
      }
    }

    this.#setBadge(document.querySelector(".container-filter-count-menu-10"), moreCount)
  }

  #updateGeoTitle() {
    const filters = FilterState.get()
    const geoName = filters.state_name || null
    const text = geoName ? `in ${geoName}` : ""
    document.querySelectorAll(".geo-filter").forEach(el => { el.textContent = text })
  }

  #setBadge(badge, count) {
    if (!badge) return
    badge.style.display = count > 0 ? "inline-block" : "none"
    const span = badge.querySelector("span")
    if (span) span.textContent = count
  }

  #reloadStatsFrame() {
    syncStatsFrame()
  }

  // Only visits if the frame has been shown at least once — avoids a background
  // request before the user has navigated to Table view.
  #reloadTableFrame() {
    if (!this.#tableLoaded) return
    this.#visitTableFrame()
  }

  #visitTableFrame() {
    Turbo.visit(`/table${window.location.search}`, { frame: "data-table" })
  }

  #loadSlider(panel) {
    this.application.getControllerForElementAndIdentifier(panel, "slider")?.load()
  }

  // Seeds a revealed slider's inputs with domain defaults so Apply sends its params.
  #populateSliderDefaults(panel) {
    this.application.getControllerForElementAndIdentifier(panel, "slider")?.populateDefaultsIfEmpty()
  }

  #loadVisibleSliders() {
    this.element.querySelectorAll("[data-controller~='slider']").forEach(panel => {
      if (!panel.classList.contains("hidden")) this.#loadSlider(panel)
    })
  }
}
