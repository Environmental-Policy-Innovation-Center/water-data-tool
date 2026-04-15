import { Controller } from "@hotwired/stimulus"
import * as FilterState from "filter_state"

// Manages filter dropdown menus — toggle open/close, outside-click dismiss, Apply.
// On Apply: collects current DOM filter state → writes to FilterState → dispatches filters:changed.
export default class extends Controller {
  connect() {
    this._outsideClick = (e) => {
      if (!e.target.closest(".filter-menu-btn") && !e.target.closest(".container-menu")) {
        this.#closeAll()
      }
    }
    document.addEventListener("click", this._outsideClick)
    this.#restoreFromUrl()
  }

  disconnect() {
    document.removeEventListener("click", this._outsideClick)
  }

  toggleMenu(event) {
    event.preventDefault()
    const btn = event.currentTarget
    const menuId = btn.dataset.menu
    const menu = document.getElementById(`container-menu-${menuId}`)
    if (!menu) return

    const isOpen = menu.style.display === "block"
    this.#closeAll()
    if (!isOpen) {
      // Align menu below the button that triggered it
      const mapRect = document.getElementById("container-map").getBoundingClientRect()
      const btnRect = btn.getBoundingClientRect()
      menu.style.left = `${btnRect.left - mapRect.left}px`
      menu.style.display = "block"
      btn.classList.add("active")
    }
  }

  apply(event) {
    event.preventDefault()
    this.#closeAll()
    FilterState.set(this.#collectFilters())
    this.#syncToUrl()
    document.dispatchEvent(new CustomEvent("filters:changed"))
  }

  toggleSelectAll(event) {
    const master = event.currentTarget
    const menu = master.closest(".container-menu")
    if (!menu) return

    const boxes = menu.querySelectorAll(".checkbox-type")
    const label = document.getElementById("type-deselect-all-txt")

    if (master.checked) {
      boxes.forEach(cb => { cb.checked = true })
      if (label) label.textContent = "Deselect all"
    } else {
      boxes.forEach(cb => { cb.checked = false })
      if (label) label.textContent = "Select all"
    }
  }

  togglePopSize(event) {
    event.preventDefault()
    const box = event.currentTarget
    box.classList.toggle("active")

    // Handle first-element border styling
    const first = document.querySelector(".pop-size-1")
    if (first) {
      if (first.classList.contains("active")) {
        first.classList.add("active-first")
      } else {
        first.classList.remove("active-first")
      }
    }
  }

  reset(event) {
    event.preventDefault()
    const menu = event.currentTarget.closest(".container-menu")
    if (!menu) return

    // Radios: check the option marked with data-default, uncheck others
    menu.querySelectorAll("input[type='radio']").forEach(r => {
      r.checked = r.hasAttribute("data-default")
    })

    // Checkboxes: restore to default state (checked if .default-checked)
    menu.querySelectorAll("input[type='checkbox']").forEach(cb => {
      cb.checked = cb.classList.contains("default-checked")
    })

    // Selects: min → first option, max → last option
    menu.querySelectorAll("select.min-select").forEach(s => { s.selectedIndex = 0 })
    menu.querySelectorAll("select.max-select").forEach(s => { s.selectedIndex = s.options.length - 1 })

    // Population size boxes: deactivate all
    menu.querySelectorAll(".pop-size-box").forEach(b => b.classList.remove("active"))

    // Place autocomplete: clear hidden field if present
    const placeInput = menu.querySelector("#place-geoid")
    if (placeInput) placeInput.value = ""
    const placeText = menu.querySelector(".js-place-search")
    if (placeText) placeText.value = ""

    this.apply(event)
  }

  // ── Private ────────────────────────────────────────────────────────────────

  #closeAll() {
    document.querySelectorAll(".container-menu").forEach(m => { m.style.display = "none" })
    document.querySelectorAll(".filter-menu-btn").forEach(b => b.classList.remove("active"))
  }

  #collectFilters() {
    const p = {}

    // --- Source: water type ---
    const wsGround = document.getElementById("ws-ground")
    const wsSurface = document.getElementById("ws-surface")
    if (wsGround?.checked) p.gw_sw_code = "GW"
    else if (wsSurface?.checked) p.gw_sw_code = "SW"

    // --- Source: source protection ---
    if (document.getElementById("has-source-water-protection")?.checked) {
      p.has_source_protection = "true"
    }

    // --- Attributes: ownership (default = all checked; only filter when some unchecked) ---
    const ownerBoxes = [...document.querySelectorAll(".checkbox-type")]
    const checkedOwners = ownerBoxes.filter(el => el.checked)
    if (checkedOwners.length > 0 && checkedOwners.length < ownerBoxes.length) {
      p.owner_type = checkedOwners.map(el => this.#ownerTypeValue(el.id))
    }

    // --- Attributes: primacy type ---
    const primacyIds = ["primacy-type-state", "primacy-type-tribal", "primacy-type-territory"]
    const checkedPrimacy = primacyIds.filter(id => document.getElementById(id)?.checked)
    if (checkedPrimacy.length > 0 && checkedPrimacy.length < primacyIds.length) {
      p.primacy_type = checkedPrimacy.map(id => this.#primacyTypeValue(id))
    }

    // --- Attributes: wholesaler / school ---
    if (document.getElementById("is-wholesaler")?.checked) p.is_wholesaler = "true"
    if (document.getElementById("is-school-or-daycare")?.checked) p.is_school_or_daycare = "true"

    // --- Boundaries: service area type ---
    const btModeled = document.getElementById("bt-modeled")
    const btSystem = document.getElementById("bt-system")
    if (btModeled?.checked) p.service_area_type = "Modeled"
    else if (btSystem?.checked) p.service_area_type = "System"

    // --- Boundaries: area range ---
    const areaMin = document.getElementById("area-min")?.value
    const areaMax = document.getElementById("area-max")?.value
    if (areaMin && areaMin !== "0") p.area_min = areaMin
    if (areaMax && areaMax !== "999999") p.area_max = areaMax

    // --- Compliance: boolean filters ---
    if (document.getElementById("compliance-open-violations")?.checked) p.has_open_violations = "true"
    if (document.getElementById("viols-health-5yrs")?.checked) p.health_violations_5yr_min = "1"
    if (document.getElementById("viols-health")?.checked) p.health_violations_10yr_min = "1"
    if (document.getElementById("viols-paperwork-5yrs")?.checked) p.paperwork_violations_5yr_min = "1"
    if (document.getElementById("viols-paperwork")?.checked) p.paperwork_violations_10yr_min = "1"

    // --- Population: size categories ---
    const popIds = ["pop-size-1", "pop-size-2", "pop-size-3", "pop-size-4", "pop-size-5"]
    const activePop = popIds.filter(cls => document.querySelector(`.${cls}`)?.classList.contains("active"))
    if (activePop.length > 0 && activePop.length < popIds.length) {
      p.pop_cat_5 = activePop.map(cls => cls.replace("pop-size-", ""))
    }

    // --- Population: density range ---
    const densityMin = document.getElementById("density-min")?.value
    const densityMax = document.getElementById("density-max")?.value
    if (densityMin && densityMin !== "0") p.density_min = densityMin
    if (densityMax && densityMax !== "999999") p.density_max = densityMax

    // --- Place geographic filter ---
    const placeGeoid = document.getElementById("place-geoid")?.value
    if (placeGeoid) {
      p.place_geoid = placeGeoid
      const placeInput = document.querySelector(".js-place-search")
      if (placeInput?.value) p.place_name = placeInput.value
    }

    return p
  }

  // Map checkbox IDs to the owner_type values stored in the DB
  #ownerTypeValue(id) {
    const map = {
      "type-federal-government": "Federal",
      "type-state-government": "State",
      "type-local-government": "Local",
      "type-native-american": "Tribal",
      "type-private": "Private",
      "type-public-private": "Public/Private"
    }
    return map[id] || id
  }

  #primacyTypeValue(id) {
    const map = {
      "primacy-type-state": "State",
      "primacy-type-tribal": "Tribal",
      "primacy-type-territory": "Territory"
    }
    return map[id] || id
  }

  #syncToUrl() {
    const url = new URL(window.location)
    url.search = FilterState.toUrlParams().toString()
    history.replaceState({}, "", url)
  }

  #restoreFromUrl() {
    if (!window.location.search) return

    const params = FilterState.fromUrlParams(window.location.search)
    if (Object.keys(params).length === 0) return

    this.#restoreDomState(params)
    FilterState.set(params)
    document.dispatchEvent(new CustomEvent("filters:changed"))
  }

  #restoreDomState(params) {
    // Source: water type
    if (params.gw_sw_code === "GW") { const el = document.getElementById("ws-ground"); if (el) el.checked = true }
    else if (params.gw_sw_code === "SW") { const el = document.getElementById("ws-surface"); if (el) el.checked = true }

    // Source protection
    if (params.has_source_protection === "true") {
      const el = document.getElementById("has-source-water-protection"); if (el) el.checked = true
    }

    // Owner types
    if (params.owner_type) {
      const valueToId = { Federal: "type-federal-government", State: "type-state-government", Local: "type-local-government", Tribal: "type-native-american", Private: "type-private", "Public/Private": "type-public-private" }
      document.querySelectorAll(".checkbox-type").forEach(cb => { cb.checked = false })
      params.owner_type.forEach(v => { const el = document.getElementById(valueToId[v]); if (el) el.checked = true })
    }

    // Primacy type
    if (params.primacy_type) {
      const valueToId = { State: "primacy-type-state", Tribal: "primacy-type-tribal", Territory: "primacy-type-territory" }
      Object.values(valueToId).forEach(id => { const el = document.getElementById(id); if (el) el.checked = false })
      params.primacy_type.forEach(v => { const el = document.getElementById(valueToId[v]); if (el) el.checked = true })
    }

    // Boolean toggles
    if (params.is_wholesaler === "true") { const el = document.getElementById("is-wholesaler"); if (el) el.checked = true }
    if (params.is_school_or_daycare === "true") { const el = document.getElementById("is-school-or-daycare"); if (el) el.checked = true }

    // Boundary type
    if (params.service_area_type === "Modeled") { const el = document.getElementById("bt-modeled"); if (el) el.checked = true }
    else if (params.service_area_type === "System") { const el = document.getElementById("bt-system"); if (el) el.checked = true }

    // Area range
    if (params.area_min) { const el = document.getElementById("area-min"); if (el) el.value = params.area_min }
    if (params.area_max) { const el = document.getElementById("area-max"); if (el) el.value = params.area_max }

    // Compliance booleans
    if (params.has_open_violations === "true") { const el = document.getElementById("compliance-open-violations"); if (el) el.checked = true }
    if (params.health_violations_5yr_min) { const el = document.getElementById("viols-health-5yrs"); if (el) el.checked = true }
    if (params.health_violations_10yr_min) { const el = document.getElementById("viols-health"); if (el) el.checked = true }
    if (params.paperwork_violations_5yr_min) { const el = document.getElementById("viols-paperwork-5yrs"); if (el) el.checked = true }
    if (params.paperwork_violations_10yr_min) { const el = document.getElementById("viols-paperwork"); if (el) el.checked = true }

    // Population categories
    if (params.pop_cat_5) {
      const catToClass = { "1": "pop-size-1", "2": "pop-size-2", "3": "pop-size-3", "4": "pop-size-4", "5": "pop-size-5" }
      params.pop_cat_5.forEach(cat => {
        const el = document.querySelector(`.${catToClass[cat]}`)
        if (el) el.classList.add("active")
      })
    }

    // Density range
    if (params.density_min) { const el = document.getElementById("density-min"); if (el) el.value = params.density_min }
    if (params.density_max) { const el = document.getElementById("density-max"); if (el) el.value = params.density_max }

    // Place geographic filter
    if (params.place_geoid) {
      const el = document.getElementById("place-geoid")
      if (el) el.value = params.place_geoid
      const input = document.querySelector(".js-place-search")
      if (input) input.value = params.place_name || params.place_geoid
    }
  }
}
