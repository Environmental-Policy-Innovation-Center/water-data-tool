import { Controller } from "@hotwired/stimulus"
import * as FilterState from "filter_state"

const POP_CAT_MAP = { "1": "<=500", "2": "501-3,300", "3": "3,301-10,000", "4": "10,001-100,000", "5": ">100,000" }
const POP_CLASS_MAP = Object.fromEntries(Object.entries(POP_CAT_MAP).map(([k, v]) => [v, `pop-size-${k}`]))

const OWNER_TYPE_MAP = {
  "type-federal-government": "Federal",
  "type-state-government":   "State",
  "type-local-government":   "Local",
  "type-native-american":    "Native American",
  "type-private":            "Private",
  "type-public-private":     "Public/Private"
}

// Single source of truth for every filter ↔ DOM mapping.
// Adding a new filter = one entry below; no other code changes needed.
// Types: 'radio' | 'bool' | 'group' | 'select' | 'pop_cat' | 'place'
const FILTERS = [
  // ── Source (menu 1) ──────────────────────────────────────────────────────
  { type: "radio",   group: 1,  param: "gw_sw_code",              ids: { "ws-ground": "Groundwater", "ws-surface": "Surface Water" } },
  { type: "bool",    group: 1,  param: "has_source_protection",   id: "has-source-water-protection", value: "true" },
  { type: "place",   group: 1,  param: "place_geoid",             id: "place-geoid", nameSelector: ".js-place-search", nameParam: "place_name" },

  // ── Attributes (menu 2) ──────────────────────────────────────────────────
  { type: "group",   group: 2,  param: "owner_type",    selector: ".checkbox-type", valueMap: OWNER_TYPE_MAP },
  { type: "group",   group: 2,  param: "primacy_type",  valueMap: { "primacy-type-state": "State", "primacy-type-tribal": "Tribal", "primacy-type-territory": "Territory" } },
  { type: "bool",    group: 2,  param: "is_wholesaler",         id: "is-wholesaler",        value: "true" },
  { type: "bool",    group: 2,  param: "is_school_or_daycare",  id: "is-school-or-daycare", value: "true" },

  // ── Boundaries (menu 3) ──────────────────────────────────────────────────
  { type: "radio",   group: 3,  param: "symbology_field", ids: { "bt-modeled": "Modeled", "bt-system": "System Sourced" } },
  { type: "select",  group: 3,  param: "area_min",        id: "area-min", sentinel: "0" },
  { type: "select",  group: 3,  param: "area_max",        id: "area-max", sentinel: "999999" },

  // ── Compliance (menu 4) ──────────────────────────────────────────────────
  { type: "bool",    group: 4,  param: "has_open_violations",          id: "compliance-open-violations", value: "true" },
  { type: "bool",    group: 4,  param: "health_violations_5yr_min",    id: "viols-health-5yrs",          value: "1" },
  { type: "bool",    group: 4,  param: "health_violations_10yr_min",   id: "viols-health",               value: "1" },
  { type: "bool",    group: 4,  param: "paperwork_violations_5yr_min", id: "viols-paperwork-5yrs",       value: "1" },
  { type: "bool",    group: 4,  param: "paperwork_violations_10yr_min",id: "viols-paperwork",            value: "1" },

  // ── Population (menu 5) ──────────────────────────────────────────────────
  { type: "pop_cat", group: 5,  param: "pop_cat_5" },
  { type: "select",  group: 5,  param: "density_min", id: "density-min", sentinel: "0" },
  { type: "select",  group: 5,  param: "density_max", id: "density-max", sentinel: "999999" },

  // ── More (menu 10) ───────────────────────────────────────────────────────
  { type: "bool",    group: 10, param: "times_funded_min",                    id: "more-has-srf-financing",          value: "1" },
  { type: "bool",    group: 10, param: "total_srf_assistance_min",            id: "more-has-srf-assistance",         value: "1" },
  { type: "bool",    group: 10, param: "total_principal_forgiveness_min",     id: "more-has-principal-forgiveness",  value: "1" },
  { type: "bool",    group: 10, param: "num_facilities_min",                  id: "more-num-facilities",             value: "1" },
  { type: "bool",    group: 10, param: "permit_effluent_violations_min",      id: "more-permit-effluent-violations", value: "1" },
  { type: "bool",    group: 10, param: "open_underground_storage_tanks_min",  id: "more-open-usts",                  value: "1" },
  { type: "bool",    group: 10, param: "risk_management_plan_facilities_min", id: "more-rmps",                       value: "1" },
  { type: "bool",    group: 10, param: "impaired_streams_303d_min",           id: "more-impaired-streams",           value: "1" },
]

// Derived from FILTERS — maps menu group number to its param keys for badge counting.
const GROUP_KEYS = FILTERS.reduce((acc, { group, param }) => {
  (acc[group] ||= []).push(param)
  return acc
}, {})

// Collects filter state → writes to FilterState → dispatches filters:changed.
// Menu open/close lives in filter_menu_controller. Responsive layout in filter_layout_controller.
export default class extends Controller {
  #statsFrame = null

  connect() {
    this.#statsFrame = document.querySelector("turbo-frame#stats-bar")
    document.addEventListener("table:show", this.#onTableShow)
    document.addEventListener("filter:layout-changed", this.#onLayoutChanged)
    this.#restoreFromUrl()
    this.#updateBadges()
  }

  disconnect() {
    document.removeEventListener("table:show", this.#onTableShow)
    document.removeEventListener("filter:layout-changed", this.#onLayoutChanged)
  }

  apply(event) {
    event.preventDefault()
    document.dispatchEvent(new CustomEvent("filter:close-all"))
    FilterState.set(this.#collectFilters())
    this.#syncToUrl()
    this.#updateBadges()
    document.dispatchEvent(new CustomEvent("filters:changed"))
    this.#reloadStatsFrame()
    this.#reloadTableFrame()
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
    event.currentTarget.classList.toggle("active")

    // First button has a distinct left-border style when active
    const first = document.querySelector(".pop-size-1")
    if (first) first.classList.toggle("active-first", first.classList.contains("active"))
  }

  reset(event) {
    event.preventDefault()
    const menu = event.currentTarget.closest(".container-menu")
    if (!menu) return
    this.#resetMenu(menu)
    this.apply(event)
  }

  #onLayoutChanged = () => this.#updateBadges()

  #onTableShow = () => {
    this.#tableLoaded = true
    this.#visitTableFrame()
  }

  #tableLoaded = false

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

  #collectFilters() {
    const p = {}

    for (const f of FILTERS) {
      switch (f.type) {
        case "radio": {
          for (const [id, val] of Object.entries(f.ids)) {
            if (document.getElementById(id)?.checked) { p[f.param] = val; break }
          }
          break
        }
        case "bool": {
          if (document.getElementById(f.id)?.checked) p[f.param] = f.value
          break
        }
        case "group": {
          const all = f.selector
            ? [...document.querySelectorAll(f.selector)]
            : Object.keys(f.valueMap).map(id => document.getElementById(id)).filter(Boolean)
          const checked = all.filter(el => el.checked)
          if (checked.length > 0 && checked.length < all.length) {
            p[f.param] = checked.map(el => f.valueMap[el.id])
          }
          break
        }
        case "select": {
          const val = document.getElementById(f.id)?.value
          if (val && val !== f.sentinel) p[f.param] = val
          break
        }
        case "pop_cat": {
          const keys = Object.keys(POP_CAT_MAP)
          const active = keys.filter(k => document.querySelector(`.pop-size-${k}`)?.classList.contains("active"))
          if (active.length > 0 && active.length < keys.length) {
            p[f.param] = active.map(k => POP_CAT_MAP[k])
          }
          break
        }
        case "place": {
          const val = document.getElementById(f.id)?.value
          if (val) {
            p[f.param] = val
            const nameEl = document.querySelector(f.nameSelector)
            if (nameEl?.value) p[f.nameParam] = nameEl.value
          }
          break
        }
      }
    }

    return p
  }

  #restoreDomState(params) {
    for (const f of FILTERS) {
      switch (f.type) {
        case "radio": {
          if (params[f.param] == null) break
          for (const [id, val] of Object.entries(f.ids)) {
            if (val === params[f.param]) {
              const el = document.getElementById(id)
              if (el) el.checked = true
              break
            }
          }
          break
        }
        case "bool": {
          if (params[f.param] !== f.value) break
          const el = document.getElementById(f.id)
          if (el) el.checked = true
          break
        }
        case "group": {
          if (!params[f.param]) break
          const all = f.selector
            ? [...document.querySelectorAll(f.selector)]
            : Object.keys(f.valueMap).map(id => document.getElementById(id)).filter(Boolean)
          const valToId = Object.fromEntries(Object.entries(f.valueMap).map(([k, v]) => [v, k]))
          all.forEach(el => { el.checked = false })
          params[f.param].forEach(v => {
            const id = valToId[v]
            if (id) { const el = document.getElementById(id); if (el) el.checked = true }
          })
          break
        }
        case "select": {
          if (!params[f.param]) break
          const el = document.getElementById(f.id)
          if (el) el.value = params[f.param]
          break
        }
        case "pop_cat": {
          if (!params[f.param]) break
          params[f.param].forEach(cat => {
            const cls = POP_CLASS_MAP[cat]
            if (!cls) return
            const el = document.querySelector(`.${cls}`)
            if (el) el.classList.add("active")
          })
          break
        }
        case "place": {
          if (!params[f.param]) break
          const el = document.getElementById(f.id)
          if (el) el.value = params[f.param]
          const nameEl = document.querySelector(f.nameSelector)
          if (nameEl) nameEl.value = params[f.nameParam] || params[f.param]
          break
        }
      }
    }
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
    this.#reloadStatsFrame()
    this.#reloadTableFrame()
  }

  #updateBadges() {
    const p = FilterState.get()

    const countKeys = (keys) => keys.filter(k => p[k] != null && p[k] !== "").length

    // Groups 1–5: if collapsed into More, add their count to More's badge instead
    let moreCount = countKeys(GROUP_KEYS[10])

    for (const [groupStr, keys] of Object.entries(GROUP_KEYS)) {
      const group = Number(groupStr)
      if (group === 10) continue

      const li = document.querySelector(`.filter-${group}`)
      const count = countKeys(keys)

      if (li?.classList.contains("hidden")) {
        moreCount += count
      } else {
        this.#setBadge(document.querySelector(`.container-filter-count-menu-${group}`), count)
      }
    }

    this.#setBadge(document.querySelector(".container-filter-count-menu-10"), moreCount)
  }

  #setBadge(badge, count) {
    if (!badge) return
    badge.style.display = count > 0 ? "inline-block" : "none"
    const span = badge.querySelector("span")
    if (span) span.textContent = count
  }

  #reloadStatsFrame() {
    if (!this.#statsFrame) return
    const newSrc = `/public_water_systems/stats?${FilterState.toUrlParams()}`
    if (this.#statsFrame.src === newSrc) return
    this.#statsFrame.src = newSrc
    document.getElementById("container-map-content-bottom")?.classList.add("has-stats")
  }

  // Only visits if the frame has been shown at least once — avoids a background
  // request before the user has navigated to Table view.
  #reloadTableFrame() {
    if (!this.#tableLoaded) return
    this.#visitTableFrame()
  }

  #visitTableFrame() {
    Turbo.visit(`/table?${FilterState.toUrlParams()}`, { frame: "data-table" })
  }
}
