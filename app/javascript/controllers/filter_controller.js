import { Controller } from "@hotwired/stimulus"
import * as FilterState from "filter_state"

const POP_CAT_MAP = { "1": "<=500", "2": "501-3,300", "3": "3,301-10,000", "4": "10,001-100,000", "5": ">100,000" }
const POP_CLASS_MAP = Object.fromEntries(Object.entries(POP_CAT_MAP).map(([k, v]) => [v, `pop-size-${k}`]))

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
    this.#setupResponsiveFilters()
    this.#restoreFromUrl()
    this.#updateBadges()
  }

  disconnect() {
    document.removeEventListener("click", this._outsideClick)
    this.#teardownResponsiveFilters()
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
      const mapRect = document.getElementById("container-map").getBoundingClientRect()
      const btnRect = btn.getBoundingClientRect()

      // Show first so offsetWidth is accurate, then clamp to avoid right-edge overflow
      menu.style.left = "0"
      menu.style.display = "block"
      btn.classList.add("active")

      const leftPos = btnRect.left - mapRect.left
      const maxLeft = mapRect.width - menu.offsetWidth - 10
      menu.style.left = `${Math.max(0, Math.min(leftPos, maxLeft))}px`
    }
  }

  apply(event) {
    event.preventDefault()
    this.#closeAll()
    FilterState.set(this.#collectFilters())
    this.#syncToUrl()
    this.#updateBadges()
    document.dispatchEvent(new CustomEvent("filters:changed"))
  }

  resetAll(event) {
    event.preventDefault()
    document.querySelectorAll(".container-menu").forEach(menu => this.#resetMenu(menu))
    this.apply(event)
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
    this.#resetMenu(menu)
    this.apply(event)
  }

  // ── Private ────────────────────────────────────────────────────────────────

  #resetMenu(menu) {
    menu.querySelectorAll("input[type='radio']").forEach(r => { r.checked = r.hasAttribute("data-default") })
    menu.querySelectorAll("input[type='checkbox']").forEach(cb => { cb.checked = cb.classList.contains("default-checked") })
    menu.querySelectorAll("select.min-select").forEach(s => { s.selectedIndex = 0 })
    menu.querySelectorAll("select.max-select").forEach(s => { s.selectedIndex = s.options.length - 1 })
    menu.querySelectorAll(".pop-size-box").forEach(b => b.classList.remove("active"))
    const placeInput = menu.querySelector("#place-geoid")
    if (placeInput) placeInput.value = ""
    const placeText = menu.querySelector(".js-place-search")
    if (placeText) placeText.value = ""
  }

  #closeAll() {
    document.querySelectorAll(".container-menu").forEach(m => { m.style.display = "none" })
    document.querySelectorAll(".filter-menu-btn").forEach(b => b.classList.remove("active"))
  }

  #collectFilters() {
    const p = {}

    // --- Source: water type ---
    const wsGround = document.getElementById("ws-ground")
    const wsSurface = document.getElementById("ws-surface")
    if (wsGround?.checked) p.gw_sw_code = "Groundwater"
    else if (wsSurface?.checked) p.gw_sw_code = "Surface Water"

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
    if (btModeled?.checked) p.symbology_field = "Modeled"
    else if (btSystem?.checked) p.symbology_field = "System Sourced"

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
      p.pop_cat_5 = activePop.map(cls => POP_CAT_MAP[cls.replace("pop-size-", "")])
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

    // --- More: funding ---
    if (document.getElementById("more-has-srf-financing")?.checked) p.times_funded_min = "1"
    if (document.getElementById("more-has-srf-assistance")?.checked) p.total_srf_assistance_min = "1"
    if (document.getElementById("more-has-principal-forgiveness")?.checked) p.total_principal_forgiveness_min = "1"

    // --- More: watershed hazards ---
    if (document.getElementById("more-num-facilities")?.checked) p.num_facilities_min = "1"
    if (document.getElementById("more-permit-effluent-violations")?.checked) p.permit_effluent_violations_min = "1"
    if (document.getElementById("more-open-usts")?.checked) p.open_underground_storage_tanks_min = "1"
    if (document.getElementById("more-rmps")?.checked) p.risk_management_plan_facilities_min = "1"
    if (document.getElementById("more-impaired-streams")?.checked) p.impaired_streams_303d_min = "1"

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
    if (params.gw_sw_code === "Groundwater") { const el = document.getElementById("ws-ground"); if (el) el.checked = true }
    else if (params.gw_sw_code === "Surface Water") { const el = document.getElementById("ws-surface"); if (el) el.checked = true }

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
    if (params.symbology_field === "Modeled") { const el = document.getElementById("bt-modeled"); if (el) el.checked = true }
    else if (params.symbology_field === "System Sourced") { const el = document.getElementById("bt-system"); if (el) el.checked = true }

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
      params.pop_cat_5.forEach(cat => {
        const cls = POP_CLASS_MAP[cat]
        if (!cls) return  // unknown value — skip
        const el = document.querySelector(`.${cls}`)
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

    // More: funding
    if (params.times_funded_min) {
      const el = document.getElementById("more-has-srf-financing")
      if (el) el.checked = true
    }
    if (params.total_srf_assistance_min) {
      const el = document.getElementById("more-has-srf-assistance")
      if (el) el.checked = true
    }
    if (params.total_principal_forgiveness_min) {
      const el = document.getElementById("more-has-principal-forgiveness")
      if (el) el.checked = true
    }

    // More: watershed hazards
    if (params.num_facilities_min) {
      const el = document.getElementById("more-num-facilities")
      if (el) el.checked = true
    }
    if (params.permit_effluent_violations_min) {
      const el = document.getElementById("more-permit-effluent-violations")
      if (el) el.checked = true
    }
    if (params.open_underground_storage_tanks_min) {
      const el = document.getElementById("more-open-usts")
      if (el) el.checked = true
    }
    if (params.risk_management_plan_facilities_min) {
      const el = document.getElementById("more-rmps")
      if (el) el.checked = true
    }
    if (params.impaired_streams_303d_min) {
      const el = document.getElementById("more-impaired-streams")
      if (el) el.checked = true
    }
  }

  #updateBadges() {
    const p = FilterState.get()

    const groupKeys = {
      1: ["gw_sw_code", "has_source_protection", "place_geoid"],
      2: ["owner_type", "primacy_type", "is_wholesaler", "is_school_or_daycare"],
      3: ["symbology_field", "area_min", "area_max"],
      4: ["has_open_violations", "health_violations_5yr_min", "health_violations_10yr_min", "paperwork_violations_5yr_min", "paperwork_violations_10yr_min"],
      5: ["pop_cat_5", "density_min", "density_max"],
      10: ["times_funded_min", "total_srf_assistance_min", "total_principal_forgiveness_min", "num_facilities_min", "permit_effluent_violations_min", "open_underground_storage_tanks_min", "risk_management_plan_facilities_min", "impaired_streams_303d_min"]
    }

    const countKeys = (keys) => keys.filter(k => {
      const val = p[k]
      return val !== undefined && val !== null && val !== ""
    }).length

    // Groups 1–5: if collapsed into More, add their count to More's badge instead
    let moreCount = countKeys(groupKeys[10])

    for (const [groupStr, keys] of Object.entries(groupKeys)) {
      const group = Number(groupStr)
      if (group === 10) continue

      const li = document.querySelector(`.filter-${group}`)
      const count = countKeys(keys)

      if (li?.classList.contains("hidden")) {
        moreCount += count
      } else {
        const badge = document.querySelector(`.container-filter-count-menu-${group}`)
        if (!badge) continue
        const span = badge.querySelector("span")
        if (count > 0) {
          badge.style.display = "inline-block"
          if (span) span.textContent = count
        } else {
          badge.style.display = "none"
        }
      }
    }

    const moreBadge = document.querySelector(".container-filter-count-menu-10")
    if (moreBadge) {
      const span = moreBadge.querySelector("span")
      if (moreCount > 0) {
        moreBadge.style.display = "inline-block"
        if (span) span.textContent = moreCount
      } else {
        moreBadge.style.display = "none"
      }
    }
  }

  // Breakpoints match the legacy app (adjusted for map container width rather than window width).
  // When a nav button hides, its content div is physically moved into the More menu so it remains
  // accessible there — same DOM-reparenting pattern as the legacy scripts-ui.js setLayout().
  #RESPONSIVE_FILTERS = [
    { num: 5, breakpoint: 1190 },  // Population
    { num: 4, breakpoint: 1040 },  // Compliance
    { num: 3, breakpoint: 880 },   // Boundaries
    { num: 2, breakpoint: 730 },   // Attributes
  ]

  #resizeObserver = null
  #lastLayoutWidth = null

  #setupResponsiveFilters() {
    this.#resizeObserver = new ResizeObserver(entries => {
      this.#closeAll()
      this.#adjustFilterLayout(entries[0].contentRect.width)
    })
    const mapEl = document.getElementById("container-map")
    if (mapEl) {
      this.#resizeObserver.observe(mapEl)
      this.#adjustFilterLayout(mapEl.clientWidth)
    }
  }

  #teardownResponsiveFilters() {
    this.#resizeObserver?.disconnect()
    this.#resizeObserver = null
  }

  #adjustFilterLayout(width) {
    // Skip if no breakpoint was crossed since the last pass — avoids badge recalc on every resize pixel
    const prev = this.#lastLayoutWidth
    const crossed = prev === null || this.#RESPONSIVE_FILTERS.some(({ breakpoint }) =>
      (prev < breakpoint) !== (width < breakpoint)
    )
    if (!crossed) return
    this.#lastLayoutWidth = width

    for (const { num, breakpoint } of this.#RESPONSIVE_FILTERS) {
      const li = document.querySelector(`.filter-${num}`)
      const items = document.getElementById(`container-menu-${num}-items`)
      const mainGrp = document.getElementById(`main-filter-grp-${num}`)
      const moreGrp = document.getElementById(`more-filter-grp-${num}`)
      if (!li || !items || !mainGrp || !moreGrp) continue

      if (width < breakpoint) {
        li.classList.add("hidden")
        // items becomes the next sibling of moreGrp — stable because moreGrp is always
        // immediately followed by items (or nothing) inside the More container
        moreGrp.insertAdjacentElement("afterend", items)
      } else {
        li.classList.remove("hidden")
        // items becomes the next sibling of mainGrp — stable because the original HTML
        // always places container-menu-N-items directly after main-filter-grp-N
        mainGrp.insertAdjacentElement("afterend", items)
      }
    }
    this.#updateBadges()
  }
}
