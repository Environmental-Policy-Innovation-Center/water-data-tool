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
// Types: 'radio' | 'bool' | 'group' | 'select' | 'pop_cat' | 'place' | 'health_subcat' | 'range'
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
  { type: "bool",    group: 4,  param: "has_open_violations", id: "compliance-open-violations", value: "true" },

  { type: "health_subcat", group: 4, parentId: "viols-health-5yrs",
    panelId: "subcat-health-5yr",
    subcats: [
      { id: "viols-groundwater-5yr",           param_min: "groundwater_rule_5yr_min",            param_max: "groundwater_rule_5yr_max",            minInputId: "min-groundwater-5yr",     maxInputId: "max-groundwater-5yr",     sliderPanelId: "slider-groundwater-5yr" },
      { id: "viols-surface-water-5yr",         param_min: "surface_water_treatment_5yr_min",     param_max: "surface_water_treatment_5yr_max",     minInputId: "min-surface-water-5yr",   maxInputId: "max-surface-water-5yr",   sliderPanelId: "slider-surface-water-5yr" },
      { id: "viols-lead-copper-5yr",           param_min: "lead_and_copper_5yr_min",             param_max: "lead_and_copper_5yr_max",             minInputId: "min-lead-copper-5yr",     maxInputId: "max-lead-copper-5yr",     sliderPanelId: "slider-lead-copper-5yr" },
      { id: "viols-radionuclides-5yr",         param_min: "radionuclides_5yr_min",               param_max: "radionuclides_5yr_max",               minInputId: "min-radionuc-5yr",        maxInputId: "max-radionuc-5yr",        sliderPanelId: "slider-radionuc-5yr" },
      { id: "viols-inorganic-5yr",             param_min: "inorganic_chemicals_5yr_min",         param_max: "inorganic_chemicals_5yr_max",         minInputId: "min-inorganic-5yr",       maxInputId: "max-inorganic-5yr",       sliderPanelId: "slider-inorganic-5yr" },
      { id: "viols-synthetic-5yr",             param_min: "synthetic_organic_chemicals_5yr_min", param_max: "synthetic_organic_chemicals_5yr_max", minInputId: "min-soc-5yr",             maxInputId: "max-soc-5yr",             sliderPanelId: "slider-soc-5yr" },
      { id: "viols-vocs-5yr",                  param_min: "volatile_organic_chemicals_5yr_min",  param_max: "volatile_organic_chemicals_5yr_max",  minInputId: "min-voc-5yr",             maxInputId: "max-voc-5yr",             sliderPanelId: "slider-voc-5yr" },
      { id: "viols-coliform-5yr",              param_min: "total_coliform_5yr_min",              param_max: "total_coliform_5yr_max",              minInputId: "min-coliform-5yr",        maxInputId: "max-coliform-5yr",        sliderPanelId: "slider-coliform-5yr" },
      { id: "viols-stage-1-disinfectants-5yr", param_min: "stage_1_disinfectants_5yr_min",       param_max: "stage_1_disinfectants_5yr_max",       minInputId: "min-stage1-dis-5yr",      maxInputId: "max-stage1-dis-5yr",      sliderPanelId: "slider-stage1-dis-5yr" },
      { id: "viols-stage-2-disinfectants-5yr", param_min: "stage_2_disinfectants_5yr_min",       param_max: "stage_2_disinfectants_5yr_max",       minInputId: "min-stage2-dis-5yr",      maxInputId: "max-stage2-dis-5yr",      sliderPanelId: "slider-stage2-dis-5yr" }
    ]
  },

  { type: "health_subcat", group: 4, parentId: "viols-health",
    panelId: "subcat-health-10yr",
    subcats: [
      { id: "viols-groundwater-10yr",           param_min: "groundwater_rule_10yr_min",            param_max: "groundwater_rule_10yr_max",            minInputId: "min-groundwater-10yr",    maxInputId: "max-groundwater-10yr",    sliderPanelId: "slider-groundwater-10yr" },
      { id: "viols-surface-water-10yr",         param_min: "surface_water_treatment_10yr_min",     param_max: "surface_water_treatment_10yr_max",     minInputId: "min-surface-water-10yr",  maxInputId: "max-surface-water-10yr",  sliderPanelId: "slider-surface-water-10yr" },
      { id: "viols-lead-copper-10yr",           param_min: "lead_and_copper_10yr_min",             param_max: "lead_and_copper_10yr_max",             minInputId: "min-lead-copper-10yr",    maxInputId: "max-lead-copper-10yr",    sliderPanelId: "slider-lead-copper-10yr" },
      { id: "viols-radionuclides-10yr",         param_min: "radionuclides_10yr_min",               param_max: "radionuclides_10yr_max",               minInputId: "min-radionuc-10yr",       maxInputId: "max-radionuc-10yr",       sliderPanelId: "slider-radionuc-10yr" },
      { id: "viols-inorganic-10yr",             param_min: "inorganic_chemicals_10yr_min",         param_max: "inorganic_chemicals_10yr_max",         minInputId: "min-inorganic-10yr",      maxInputId: "max-inorganic-10yr",      sliderPanelId: "slider-inorganic-10yr" },
      { id: "viols-synthetic-10yr",             param_min: "synthetic_organic_chemicals_10yr_min", param_max: "synthetic_organic_chemicals_10yr_max", minInputId: "min-soc-10yr",            maxInputId: "max-soc-10yr",            sliderPanelId: "slider-soc-10yr" },
      { id: "viols-vocs-10yr",                  param_min: "volatile_organic_chemicals_10yr_min",  param_max: "volatile_organic_chemicals_10yr_max",  minInputId: "min-voc-10yr",            maxInputId: "max-voc-10yr",            sliderPanelId: "slider-voc-10yr" },
      { id: "viols-coliform-10yr",              param_min: "total_coliform_10yr_min",              param_max: "total_coliform_10yr_max",              minInputId: "min-coliform-10yr",       maxInputId: "max-coliform-10yr",       sliderPanelId: "slider-coliform-10yr" },
      { id: "viols-stage-1-disinfectants-10yr", param_min: "stage_1_disinfectants_10yr_min",       param_max: "stage_1_disinfectants_10yr_max",       minInputId: "min-stage1-dis-10yr",     maxInputId: "max-stage1-dis-10yr",     sliderPanelId: "slider-stage1-dis-10yr" },
      { id: "viols-stage-2-disinfectants-10yr", param_min: "stage_2_disinfectants_10yr_min",       param_max: "stage_2_disinfectants_10yr_max",       minInputId: "min-stage2-dis-10yr",     maxInputId: "max-stage2-dis-10yr",     sliderPanelId: "slider-stage2-dis-10yr" }
    ]
  },

  { type: "range", group: 4,
    param_min: "paperwork_violations_5yr_min", param_max: "paperwork_violations_5yr_max",
    parentId: "viols-paperwork-5yrs", panelId: "subcat-paperwork-5yr",
    minInputId: "min-paperwork-5yr", maxInputId: "max-paperwork-5yr" },

  { type: "range", group: 4,
    param_min: "paperwork_violations_10yr_min", param_max: "paperwork_violations_10yr_max",
    parentId: "viols-paperwork", panelId: "subcat-paperwork-10yr",
    minInputId: "min-paperwork", maxInputId: "max-paperwork" },

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

// Filters with .param contribute a single URL key counted directly.
// health_subcat and range omit .param and are counted separately below.
const GROUP_KEYS = FILTERS.reduce((acc, f) => {
  if (f.param) (acc[f.group] ||= []).push(f.param)
  return acc
}, {})

const HEALTH_SUBCAT_FILTERS = FILTERS.filter(f => f.type === "health_subcat")
const RANGE_FILTERS = FILTERS.filter(f => f.type === "range")

// Collects filter state → writes to FilterState → dispatches filters:changed.
// Menu open/close lives in filter_menu_controller. Responsive layout in filter_layout_controller.
export default class extends Controller {
  #statsFrame = null
  #tableLoaded = false

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

  // On check: opens panel and checks all subcats + shows their histogram panels.
  // On uncheck: unchecks all subcats + hides/resets all their histogram panels.
  toggleSubcat(event) {
    const checkbox = event.currentTarget
    const panelId = checkbox.dataset.panelId
    const panel = panelId && document.getElementById(panelId)
    if (!panel) return
    const filter = HEALTH_SUBCAT_FILTERS.find(f => f.panelId === panelId)

    if (checkbox.checked) {
      panel.classList.remove("hidden")
      this.#setToggleArrow(panelId, true)
      panel.querySelectorAll("input[type='checkbox']").forEach(cb => { cb.checked = true })
      filter?.subcats.forEach(s => {
        if (!s.sliderPanelId) return
        const sliderPanel = document.getElementById(s.sliderPanelId)
        if (!sliderPanel) return
        sliderPanel.classList.remove("hidden")
        this.application.getControllerForElementAndIdentifier(sliderPanel, "slider")?.populateDefaultsIfEmpty()
      })
    } else {
      panel.querySelectorAll("input[type='checkbox']").forEach(cb => { cb.checked = false })
      filter?.subcats.forEach(s => {
        if (s.sliderPanelId) this.#hideAndResetSlider(document.getElementById(s.sliderPanelId))
      })
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
  }

  // Keeps parent checkbox in sync when subcats are individually toggled.
  // Also shows/hides the changed subcat's histogram panel.
  syncParentFromSubcat(event) {
    const panel = event.currentTarget
    const filter = HEALTH_SUBCAT_FILTERS.find(f => f.panelId === panel.id)
    if (!filter) return

    const anyChecked = filter.subcats.some(s => document.getElementById(s.id)?.checked)
    const parentEl = document.getElementById(filter.parentId)
    if (parentEl) parentEl.checked = anyChecked

    const changedSubcat = filter.subcats.find(s => s.id === event.target.id)
    if (!changedSubcat?.sliderPanelId) return
    const sliderPanel = document.getElementById(changedSubcat.sliderPanelId)
    if (!sliderPanel) return

    if (event.target.checked) {
      sliderPanel.classList.remove("hidden")
      this.application.getControllerForElementAndIdentifier(sliderPanel, "slider")?.populateDefaultsIfEmpty()
    } else {
      this.#hideAndResetSlider(sliderPanel)
    }
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
    btn.querySelector("svg")?.classList.toggle("rotate-180", expanded)
  }

  #onLayoutChanged = () => this.#updateBadges()

  #onTableShow = () => {
    this.#tableLoaded = true
    this.#visitTableFrame()
  }

  #resetMenu(menu) {
    menu.querySelectorAll("input[type='radio']").forEach(r => { r.checked = r.hasAttribute("data-default") })
    menu.querySelectorAll("input[type='checkbox']").forEach(cb => { cb.checked = cb.classList.contains("default-checked") })
    menu.querySelectorAll("[data-subcat-panel]").forEach(panel => {
      panel.classList.add("hidden")
      panel.querySelectorAll("input[type='hidden']").forEach(inp => { inp.value = "" })
      const sliderCtrl = this.application.getControllerForElementAndIdentifier(panel, "slider")
      sliderCtrl?.resetToFullRange()
    })
    HEALTH_SUBCAT_FILTERS.forEach(f => {
      if (!menu.contains(document.getElementById(f.panelId))) return
      f.subcats.forEach(s => {
        if (s.sliderPanelId) this.#hideAndResetSlider(document.getElementById(s.sliderPanelId))
      })
    })
    menu.querySelectorAll("button[data-panel-id]").forEach(btn => {
      btn.setAttribute("aria-expanded", "false")
      btn.querySelector("svg")?.classList.remove("rotate-180")
    })
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
        case "health_subcat": {
          const parent = document.getElementById(f.parentId)
          if (!parent?.checked) break
          for (const s of f.subcats) {
            if (!document.getElementById(s.id)?.checked) continue
            const minVal = document.getElementById(s.minInputId)?.value
            const maxVal = document.getElementById(s.maxInputId)?.value
            if (minVal) p[s.param_min] = minVal
            if (maxVal) p[s.param_max] = maxVal
          }
          break
        }
        case "range": {
          const parent = document.getElementById(f.parentId)
          if (!parent?.checked) break
          const minVal = document.getElementById(f.minInputId)?.value
          const maxVal = document.getElementById(f.maxInputId)?.value
          if (minVal) p[f.param_min] = minVal
          if (maxVal) p[f.param_max] = maxVal
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
        case "health_subcat": {
          const anySubcatSet = f.subcats.some(s => params[s.param_min] != null || params[s.param_max] != null)
          if (!anySubcatSet) break

          const parent = document.getElementById(f.parentId)
          if (parent) parent.checked = true
          const panel = document.getElementById(f.panelId)
          if (panel) panel.classList.remove("hidden")
          this.#setToggleArrow(f.panelId, true)

          f.subcats.forEach(s => {
            const hasMin = params[s.param_min] != null
            const hasMax = params[s.param_max] != null
            const el = document.getElementById(s.id)
            if (el) el.checked = hasMin || hasMax
            if (hasMin) {
              const minEl = document.getElementById(s.minInputId)
              if (minEl) minEl.value = params[s.param_min]
            }
            if (hasMax) {
              const maxEl = document.getElementById(s.maxInputId)
              if (maxEl) maxEl.value = params[s.param_max]
            }
            if ((hasMin || hasMax) && s.sliderPanelId) {
              const sliderPanel = document.getElementById(s.sliderPanelId)
              if (sliderPanel) sliderPanel.classList.remove("hidden")
            }
          })
          break
        }
        case "range": {
          const minSet = params[f.param_min] != null
          const maxSet = params[f.param_max] != null
          if (!minSet && !maxSet) break

          const parent = document.getElementById(f.parentId)
          if (parent) parent.checked = true
          const panel = document.getElementById(f.panelId)
          if (panel) panel.classList.remove("hidden")
          this.#setToggleArrow(f.panelId, true)

          const minEl = document.getElementById(f.minInputId)
          if (minEl && minSet) minEl.value = params[f.param_min]
          const maxEl = document.getElementById(f.maxInputId)
          if (maxEl && maxSet) maxEl.value = params[f.param_max]
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

    const countHealthSubcats = (group) =>
      HEALTH_SUBCAT_FILTERS.filter(f => f.group === group).filter(f =>
        f.subcats.some(s => p[s.param_min] != null || p[s.param_max] != null)
      ).length

    const countRanges = (group) =>
      RANGE_FILTERS.filter(f => f.group === group).filter(f =>
        p[f.param_min] != null || p[f.param_max] != null
      ).length

    // Groups 1–5: if collapsed into More, add their count to More's badge instead
    let moreCount = countKeys(GROUP_KEYS[10] || [])

    for (const [groupStr, keys] of Object.entries(GROUP_KEYS)) {
      const group = Number(groupStr)
      if (group === 10) continue

      const li = document.querySelector(`.filter-${group}`)
      const count = countKeys(keys) + countHealthSubcats(group) + countRanges(group)

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
