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
    document.dispatchEvent(new CustomEvent("filters:changed"))
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
}
