import { Controller } from "@hotwired/stimulus"
import * as FilterState from "filter_state"
import { syncStatsFrame } from "stats_frame"
import * as SelectionState from "selection_state"
import { decodeState, colsFromUrl, sortFromUrl, buildEncodedParam } from "url_state_codec"

const POP_CAT_MAP = { "1": "<=500", "2": "501-3,300", "3": "3,301-10,000", "4": "10,001-100,000", "5": ">100,000" }
const POP_CLASS_MAP = Object.fromEntries(Object.entries(POP_CAT_MAP).map(([k, v]) => [v, `pop-size-${k}`]))

const OWNER_TYPE_MAP = {
  "type-federal-government": "Federal",
  "type-local-government": "Local",
  "type-native-american": "Native American",
  "type-private": "Private",
  "type-public-private": "Public/Private",
  "type-state-government": "State",
}

const PRIMACY_TYPE_MAP = {
  "primacy-type-state": "State",
  "primacy-type-territory": "Territory",
  "primacy-type-tribal": "Tribal",
}

const RATE_TIER_BTN_MAP = {
  "rate-tier-lt125":   "under_125",
  "rate-tier-125-249": "tier_125_249",
  "rate-tier-250-499": "tier_250_499",
  "rate-tier-500-749": "tier_500_749",
  "rate-tier-750-999": "tier_750_999",
  "rate-tier-gt1000":  "over_1000",
}
const RATE_TIER_ID_MAP = Object.fromEntries(Object.entries(RATE_TIER_BTN_MAP).map(([id, v]) => [v, id]))

// Filter ↔ DOM wiring (IDs, value maps). Canonical param/column keys: config/filters.yml → FilterRegistry,
// embedded as #filter-registry-config JSON — extend FilterRegistry when adding backend-facing keys.
// Per-entry key order: type → group → id (if any) → param | parentId → panelId → param_min → param_max → …rest.
// subcat rows: id → param_min → param_max → minInputId → maxInputId → sliderPanelId (column-aligned within each subcats: [] block).
// Types: 'radio' | 'bool' | 'group' | 'range_select' | 'pop_cat' | 'place' | 'subcat_panel' | 'range'
const FILTERS = [
  // ── Source (menu 1) ──────────────────────────────────────────────────────
  { type: "radio", group: 1, param: "gw_sw_code", ids: { "ws-ground": "Groundwater", "ws-surface": "Surface Water" } },
  { type: "bool",  group: 1, id: "has-source-water-protection", param: "has_source_protection", value: "true" },
  { type: "place", group: 1, id: "place-geoid", param: "place_geoid", nameSelector: ".js-place-search", nameParam: "place_name" },

  // ── Attributes (menu 2) ──────────────────────────────────────────────────
  { type: "group", group: 2, param: "owner_type",        selector: ".checkbox-type",    valueMap: OWNER_TYPE_MAP },
  { type: "group", group: 2, param: "primacy_type",                                     valueMap: PRIMACY_TYPE_MAP },
  { type: "bool",  group: 2, id: "is-wholesaler",        param: "is_wholesaler",        value: "true" },
  { type: "bool",  group: 2, id: "is-school-or-daycare", param: "is_school_or_daycare", value: "true" },

  // ── Boundaries (menu 3) ──────────────────────────────────────────────────
  { type: "radio",  group: 3, param: "symbology_field", ids: { "bt-modeled": "Modeled", "bt-system": "System Sourced" } },
  { type: "range_select", group: 3, param_min: "area_min", param_max: "area_max", minInputId: "area-min", maxInputId: "area-max", minSentinel: "0", maxSentinel: "999999" },

  // ── Compliance (menu 4) ──────────────────────────────────────────────────
  { type: "bool",  group: 4, id: "compliance-open-violations", param: "has_open_violations", value: "true" },

  { type: "subcat_panel", group: 4, parentId: "viols-health-5yrs", panelId: "subcat-health-5yr", subcats: [
    { id: "viols-groundwater-5yr",           param_min: "groundwater_rule_5yr_min",            param_max: "groundwater_rule_5yr_max",            minInputId: "min-groundwater-5yr",   maxInputId: "max-groundwater-5yr",   sliderPanelId: "slider-groundwater-5yr" },
    { id: "viols-surface-water-5yr",         param_min: "surface_water_treatment_5yr_min",     param_max: "surface_water_treatment_5yr_max",     minInputId: "min-surface-water-5yr", maxInputId: "max-surface-water-5yr", sliderPanelId: "slider-surface-water-5yr" },
    { id: "viols-lead-copper-5yr",           param_min: "lead_and_copper_5yr_min",             param_max: "lead_and_copper_5yr_max",             minInputId: "min-lead-copper-5yr",   maxInputId: "max-lead-copper-5yr",   sliderPanelId: "slider-lead-copper-5yr" },
    { id: "viols-radionuclides-5yr",         param_min: "radionuclides_5yr_min",               param_max: "radionuclides_5yr_max",               minInputId: "min-radionuc-5yr",      maxInputId: "max-radionuc-5yr",      sliderPanelId: "slider-radionuc-5yr" },
    { id: "viols-inorganic-5yr",             param_min: "inorganic_chemicals_5yr_min",         param_max: "inorganic_chemicals_5yr_max",         minInputId: "min-inorganic-5yr",     maxInputId: "max-inorganic-5yr",     sliderPanelId: "slider-inorganic-5yr" },
    { id: "viols-synthetic-5yr",             param_min: "synthetic_organic_chemicals_5yr_min", param_max: "synthetic_organic_chemicals_5yr_max", minInputId: "min-soc-5yr",           maxInputId: "max-soc-5yr",           sliderPanelId: "slider-soc-5yr" },
    { id: "viols-vocs-5yr",                  param_min: "volatile_organic_chemicals_5yr_min",  param_max: "volatile_organic_chemicals_5yr_max",  minInputId: "min-voc-5yr",           maxInputId: "max-voc-5yr",           sliderPanelId: "slider-voc-5yr" },
    { id: "viols-coliform-5yr",              param_min: "total_coliform_5yr_min",              param_max: "total_coliform_5yr_max",              minInputId: "min-coliform-5yr",      maxInputId: "max-coliform-5yr",      sliderPanelId: "slider-coliform-5yr" },
    { id: "viols-stage-1-disinfectants-5yr", param_min: "stage_1_disinfectants_5yr_min",       param_max: "stage_1_disinfectants_5yr_max",       minInputId: "min-stage1-dis-5yr",    maxInputId: "max-stage1-dis-5yr",    sliderPanelId: "slider-stage1-dis-5yr" },
    { id: "viols-stage-2-disinfectants-5yr", param_min: "stage_2_disinfectants_5yr_min",       param_max: "stage_2_disinfectants_5yr_max",       minInputId: "min-stage2-dis-5yr",    maxInputId: "max-stage2-dis-5yr",    sliderPanelId: "slider-stage2-dis-5yr" },
  ] },

  { type: "subcat_panel", group: 4, parentId: "viols-health", panelId: "subcat-health-10yr", subcats: [
    { id: "viols-groundwater-10yr",           param_min: "groundwater_rule_10yr_min",            param_max: "groundwater_rule_10yr_max",            minInputId: "min-groundwater-10yr",   maxInputId: "max-groundwater-10yr",   sliderPanelId: "slider-groundwater-10yr" },
    { id: "viols-surface-water-10yr",         param_min: "surface_water_treatment_10yr_min",     param_max: "surface_water_treatment_10yr_max",     minInputId: "min-surface-water-10yr", maxInputId: "max-surface-water-10yr", sliderPanelId: "slider-surface-water-10yr" },
    { id: "viols-lead-copper-10yr",           param_min: "lead_and_copper_10yr_min",             param_max: "lead_and_copper_10yr_max",             minInputId: "min-lead-copper-10yr",   maxInputId: "max-lead-copper-10yr",   sliderPanelId: "slider-lead-copper-10yr" },
    { id: "viols-radionuclides-10yr",         param_min: "radionuclides_10yr_min",               param_max: "radionuclides_10yr_max",               minInputId: "min-radionuc-10yr",      maxInputId: "max-radionuc-10yr",      sliderPanelId: "slider-radionuc-10yr" },
    { id: "viols-inorganic-10yr",             param_min: "inorganic_chemicals_10yr_min",         param_max: "inorganic_chemicals_10yr_max",         minInputId: "min-inorganic-10yr",     maxInputId: "max-inorganic-10yr",     sliderPanelId: "slider-inorganic-10yr" },
    { id: "viols-synthetic-10yr",             param_min: "synthetic_organic_chemicals_10yr_min", param_max: "synthetic_organic_chemicals_10yr_max", minInputId: "min-soc-10yr",           maxInputId: "max-soc-10yr",           sliderPanelId: "slider-soc-10yr" },
    { id: "viols-vocs-10yr",                  param_min: "volatile_organic_chemicals_10yr_min",  param_max: "volatile_organic_chemicals_10yr_max",  minInputId: "min-voc-10yr",           maxInputId: "max-voc-10yr",           sliderPanelId: "slider-voc-10yr" },
    { id: "viols-coliform-10yr",              param_min: "total_coliform_10yr_min",              param_max: "total_coliform_10yr_max",              minInputId: "min-coliform-10yr",      maxInputId: "max-coliform-10yr",      sliderPanelId: "slider-coliform-10yr" },
    { id: "viols-stage-1-disinfectants-10yr", param_min: "stage_1_disinfectants_10yr_min",       param_max: "stage_1_disinfectants_10yr_max",       minInputId: "min-stage1-dis-10yr",    maxInputId: "max-stage1-dis-10yr",    sliderPanelId: "slider-stage1-dis-10yr" },
    { id: "viols-stage-2-disinfectants-10yr", param_min: "stage_2_disinfectants_10yr_min",       param_max: "stage_2_disinfectants_10yr_max",       minInputId: "min-stage2-dis-10yr",    maxInputId: "max-stage2-dis-10yr",    sliderPanelId: "slider-stage2-dis-10yr" },
  ] },

  { type: "range", group: 4, parentId: "viols-paperwork-5yrs",  panelId: "subcat-paperwork-5yr",   param_min: "paperwork_violations_5yr_min",   param_max: "paperwork_violations_5yr_max",   minInputId: "min-paperwork-5yr",  maxInputId: "max-paperwork-5yr" },
  { type: "range", group: 4, parentId: "viols-paperwork",       panelId: "subcat-paperwork-10yr",  param_min: "paperwork_violations_10yr_min",  param_max: "paperwork_violations_10yr_max",  minInputId: "min-paperwork",      maxInputId: "max-paperwork" },

  // ── Population (menu 5) ──────────────────────────────────────────────────
  { type: "pop_cat", group: 5, param: "pop_cat_5" },
  { type: "range_select", group: 5, param_min: "density_min", param_max: "density_max", minInputId: "density-min", maxInputId: "density-max", minSentinel: "0", maxSentinel: "999999" },

  // ── Change (alphabetical by param_min) ───────────────────────────────────
  { type: "range", group: 5, parentId: "trend-mhi-change",  panelId: "subcat-mhi-change",  param_min: "mhi_pct_change_capped_min",         param_max: "mhi_pct_change_capped_max",         minInputId: "min-mhi-change",  maxInputId: "max-mhi-change" },
  { type: "range", group: 5, parentId: "trend-pop-change",  panelId: "subcat-pop-change",  param_min: "population_pct_change_capped_min",  param_max: "population_pct_change_capped_max",  minInputId: "min-pop-change",  maxInputId: "max-pop-change" },

  // ── Socioeconomics (alphabetical by param_min) ───────────────────────────
  { type: "range", group: 5, parentId: "more-age-over-61",        panelId: "subcat-age-over-61",        param_min: "age_over_61_rate_min",         param_max: "age_over_61_rate_max",         minInputId: "min-age-over-61",        maxInputId: "max-age-over-61" },
  { type: "range", group: 5, parentId: "more-age-under-5",        panelId: "subcat-age-under-5",        param_min: "age_under_5_rate_min",         param_max: "age_under_5_rate_max",         minInputId: "min-age-under-5",        maxInputId: "max-age-under-5" },
  { type: "range", group: 5, parentId: "more-bachelors-rate",     panelId: "subcat-bachelors-rate",     param_min: "bachelors_degree_rate_min",    param_max: "bachelors_degree_rate_max",    minInputId: "min-bachelors-rate",     maxInputId: "max-bachelors-rate" },
  { type: "range", group: 5, parentId: "more-median-income",      panelId: "subcat-median-income",      param_min: "median_household_income_min",  param_max: "median_household_income_max",  minInputId: "min-median-income",      maxInputId: "max-median-income" },
  { type: "range", group: 5, parentId: "more-poverty-rate",       panelId: "subcat-poverty-rate",       param_min: "poverty_rate_min",             param_max: "poverty_rate_max",             minInputId: "min-poverty-rate",       maxInputId: "max-poverty-rate" },
  { type: "range", group: 5, parentId: "more-unemployment-rate",  panelId: "subcat-unemployment-rate",  param_min: "unemployment_rate_min",        param_max: "unemployment_rate_max",        minInputId: "min-unemployment-rate",  maxInputId: "max-unemployment-rate" },

  // ── Race/Ethnicity (alphabetical by param_min) ────────────────────────────
  { type: "range", group: 5, parentId: "more-aian-rate",        panelId: "subcat-aian-rate",        param_min: "aian_rate_min",        param_max: "aian_rate_max",        minInputId: "min-aian-rate",        maxInputId: "max-aian-rate" },
  { type: "range", group: 5, parentId: "more-asian-rate",       panelId: "subcat-asian-rate",       param_min: "asian_rate_min",       param_max: "asian_rate_max",       minInputId: "min-asian-rate",       maxInputId: "max-asian-rate" },
  { type: "range", group: 5, parentId: "more-black-rate",       panelId: "subcat-black-rate",       param_min: "black_rate_min",       param_max: "black_rate_max",       minInputId: "min-black-rate",       maxInputId: "max-black-rate" },
  { type: "range", group: 5, parentId: "more-hispanic-rate",    panelId: "subcat-hispanic-rate",    param_min: "hispanic_rate_min",    param_max: "hispanic_rate_max",    minInputId: "min-hispanic-rate",    maxInputId: "max-hispanic-rate" },
  { type: "range", group: 5, parentId: "more-mixed-race-rate",  panelId: "subcat-mixed-race-rate",  param_min: "mixed_race_rate_min",  param_max: "mixed_race_rate_max",  minInputId: "min-mixed-race-rate",  maxInputId: "max-mixed-race-rate" },
  { type: "range", group: 5, parentId: "more-napi-rate",        panelId: "subcat-napi-rate",        param_min: "napi_rate_min",        param_max: "napi_rate_max",        minInputId: "min-napi-rate",        maxInputId: "max-napi-rate" },
  { type: "range", group: 5, parentId: "more-other-race-rate",  panelId: "subcat-other-race-rate",  param_min: "other_race_rate_min",  param_max: "other_race_rate_max",  minInputId: "min-other-race-rate",  maxInputId: "max-other-race-rate" },
  { type: "range", group: 5, parentId: "more-poc-rate",         panelId: "subcat-poc-rate",         param_min: "poc_rate_min",         param_max: "poc_rate_max",         minInputId: "min-poc-rate",         maxInputId: "max-poc-rate" },
  { type: "range", group: 5, parentId: "more-white-rate",       panelId: "subcat-white-rate",       param_min: "white_rate_min",       param_max: "white_rate_max",       minInputId: "min-white-rate",       maxInputId: "max-white-rate" },

  // ── Vulnerability (alphabetical by param_min) ─────────────────────────────
  { type: "range", group: 5, parentId: "more-cejst", panelId: "subcat-cejst", param_min: "cejst_disadvantaged_pct_min", param_max: "cejst_disadvantaged_pct_max", minInputId: "min-cejst", maxInputId: "max-cejst" },
  { type: "range", group: 5, parentId: "more-cvi",   panelId: "subcat-cvi",   param_min: "cvi_overall_score_min",       param_max: "cvi_overall_score_max",       minInputId: "min-cvi",   maxInputId: "max-cvi" },
  { type: "range", group: 5, parentId: "more-svi",   panelId: "subcat-svi",   param_min: "svi_overall_pctl_min",        param_max: "svi_overall_pctl_max",        minInputId: "min-svi",   maxInputId: "max-svi" },

  // ── More (menu 10) ───────────────────────────────────────────────────────
  // ── Financial ─────────────────────────────────────────────────────────────
  { type: "rate_tier", group: 10, param: "most_common_rate_tier" },

  // ── Funding (alphabetical by param_min) ───────────────────────────────────
  { type: "range", group: 10, parentId: "more-has-srf-financing",          panelId: "subcat-srf-financing",    param_min: "times_funded_min",                 param_max: "times_funded_max",                 minInputId: "min-srf-financing",    maxInputId: "max-srf-financing" },
  { type: "range", group: 10, parentId: "more-has-principal-forgiveness",  panelId: "subcat-srf-forgiveness",  param_min: "total_principal_forgiveness_min",  param_max: "total_principal_forgiveness_max",  minInputId: "min-srf-forgiveness",  maxInputId: "max-srf-forgiveness" },
  { type: "range", group: 10, parentId: "more-has-srf-assistance",         panelId: "subcat-srf-assistance",   param_min: "total_srf_assistance_min",         param_max: "total_srf_assistance_max",         minInputId: "min-srf-assistance",   maxInputId: "max-srf-assistance" },

  // ── Environmental — Watershed Hazards (nested subcat_panel, same UX as Compliance health) ─
  { type: "subcat_panel", group: 10, parentId: "more-watershed-hazards", panelId: "subcat-watershed-hazards", subcats: [
    { id: "more-num-facilities",             param_min: "num_facilities_min",                  param_max: "num_facilities_max",                  minInputId: "min-num-facilities",    maxInputId: "max-num-facilities",    sliderPanelId: "slider-num-facilities" },
    { id: "more-permit-effluent-violations", param_min: "permit_effluent_violations_min",      param_max: "permit_effluent_violations_max",      minInputId: "min-permit-violations", maxInputId: "max-permit-violations", sliderPanelId: "slider-permit-violations" },
    { id: "more-open-usts",                  param_min: "open_underground_storage_tanks_min",  param_max: "open_underground_storage_tanks_max",  minInputId: "min-open-usts",         maxInputId: "max-open-usts",         sliderPanelId: "slider-open-usts" },
    { id: "more-rmps",                       param_min: "risk_management_plan_facilities_min", param_max: "risk_management_plan_facilities_max", minInputId: "min-rmps",              maxInputId: "max-rmps",              sliderPanelId: "slider-rmps" },
    { id: "more-impaired-streams",           param_min: "impaired_streams_303d_min",           param_max: "impaired_streams_303d_max",           minInputId: "min-impaired-streams",  maxInputId: "max-impaired-streams",  sliderPanelId: "slider-impaired-streams" },
  ] },
]

const GROUP_TYPE_FILTERS   = FILTERS.filter(f => f.type === "group")
const POP_CAT_FILTERS      = FILTERS.filter(f => f.type === "pop_cat")
const RATE_TIER_FILTERS    = FILTERS.filter(f => f.type === "rate_tier")
const SUBCAT_PANEL_FILTERS = FILTERS.filter(f => f.type === "subcat_panel")
const RANGE_FILTERS        = FILTERS.filter(f => f.type === "range")
const RANGE_SELECT_FILTERS = FILTERS.filter(f => f.type === "range_select")

// Only scalar types (radio, bool, place) have a single param counted directly from FilterState.
// Array params (group, pop_cat) and min/max pairs (range, range_select, subcat_panel) have their own counters.
const SCALAR_TYPES = new Set(["radio", "bool", "place"])
const GROUP_KEYS = {}
for (const { type, group, param } of FILTERS) {
  if (SCALAR_TYPES.has(type)) (GROUP_KEYS[group] ||= []).push(param)
}

// Collects filter state → writes to FilterState → dispatches filters:changed.
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
    this.#syncToUrl()
    this.#updateBadges()
    document.dispatchEvent(new CustomEvent("filters:changed"))
    this.dispatch("applied")
    this.#reloadStatsFrame()
    this.#reloadTableFrame()
  }

  resetAll(event) {
    event.preventDefault()
    document.querySelectorAll(".filter-dropdown").forEach(menu => this.#resetMenu(menu))
    this.apply(event)
  }

  toggleSelectAll(event) {
    const selectAll = event.currentTarget
    const menu = selectAll.closest(".filter-dropdown")
    if (!menu) return
    menu.querySelectorAll(".checkbox-type").forEach(cb => { cb.checked = selectAll.checked })
    this.#syncTypeLabel(selectAll.checked)
  }

  syncSelectAll(event) {
    const menu = event.currentTarget.closest(".filter-dropdown")
    if (!menu) return
    const selectAll = menu.querySelector(".select-all")
    if (!selectAll) return
    const allChecked = [...menu.querySelectorAll(".checkbox-type")].every(cb => cb.checked)
    selectAll.checked = allChecked
    this.#syncTypeLabel(allChecked)
  }

  togglePopSize(event) {
    event.preventDefault()
    event.currentTarget.classList.toggle("active")
  }

  toggleRateTierPanel(event) {
    event.preventDefault()
    const panelId = event.currentTarget.dataset.panelId
    const panel = panelId && document.getElementById(panelId)
    if (!panel) return
    panel.classList.toggle("hidden")
    this.#setToggleArrow(panelId, !panel.classList.contains("hidden"))
    event.currentTarget.checked = this.#rateTierHasSelection()
  }

  toggleRateTier(event) {
    event.preventDefault()
    event.currentTarget.classList.toggle("active")
    this.#syncRateTierParent()
  }

  onRateTierNoInfoChange() {
    this.#syncRateTierParent()
  }

  reset(event) {
    event.preventDefault()
    const menu = event.currentTarget.closest(".filter-dropdown")
    if (!menu) return
    this.#resetMenu(menu)
    this.apply(event)
  }

  // On check: opens panel and checks all subcats; histogram panels stay collapsed until manually opened.
  // On uncheck: unchecks all subcats + hides/resets all their histogram panels.
  toggleSubcat(event) {
    const checkbox = event.currentTarget
    const panelId = checkbox.dataset.panelId
    const panel = panelId && document.getElementById(panelId)
    if (!panel) return
    const filter = SUBCAT_PANEL_FILTERS.find(f => f.panelId === panelId)

    if (checkbox.checked) {
      panel.classList.remove("hidden")
      this.#setToggleArrow(panelId, true)
      this.#loadSlider(panel)
      panel.querySelectorAll("input[type='checkbox']").forEach(cb => { cb.checked = true })
      filter?.subcats.forEach(s => {
        if (!s.sliderPanelId) return
        const sliderPanel = document.getElementById(s.sliderPanelId)
        if (!sliderPanel) return
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
    if (willShow) this.#loadSlider(panel)
  }

  // Keeps parent checkbox in sync when subcats are individually toggled.
  // Also shows/hides the changed subcat's histogram panel.
  syncParentFromSubcat(event) {
    const panel = event.currentTarget
    const filter = SUBCAT_PANEL_FILTERS.find(f => f.panelId === panel.id)
    if (!filter) return

    const checkedCount = filter.subcats.filter(s => document.getElementById(s.id)?.checked).length
    const changedSubcat = filter.subcats.find(s => s.id === event.target.id)
    const parentEl = document.getElementById(filter.parentId)
    if (parentEl) {
      parentEl.checked = checkedCount === filter.subcats.length
      parentEl.indeterminate = checkedCount > 0 && checkedCount < filter.subcats.length
    }
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

  #rateTierHasSelection() {
    return Object.keys(RATE_TIER_BTN_MAP).some(id => document.getElementById(id)?.classList.contains("active"))
      || document.getElementById("rate-tier-no-info")?.checked
  }

  #syncRateTierParent() {
    const parentCb = document.getElementById("more-rate-tier")
    if (parentCb) parentCb.checked = this.#rateTierHasSelection()
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
    menu.querySelectorAll("[data-subcat-panel]").forEach(panel => {
      panel.classList.add("hidden")
      panel.querySelectorAll("input[type='hidden']").forEach(inp => { inp.value = "" })
      const sliderCtrl = this.application.getControllerForElementAndIdentifier(panel, "slider")
      sliderCtrl?.resetToFullRange()
    })
    SUBCAT_PANEL_FILTERS.forEach(f => {
      if (!menu.contains(document.getElementById(f.panelId))) return
      f.subcats.forEach(s => {
        if (s.sliderPanelId) this.#hideAndResetSlider(document.getElementById(s.sliderPanelId))
      })
    })
    RANGE_FILTERS.forEach(f => {
      const el = document.getElementById(f.panelId)
      if (!el || !menu.contains(el)) return
      this.#hideAndResetSlider(el)
    })
    menu.querySelectorAll("button[data-panel-id]").forEach(btn => {
      this.#setToggleArrow(btn.dataset.panelId, false)
    })
    menu.querySelectorAll("select.min-select").forEach(s => { s.selectedIndex = 0 })
    menu.querySelectorAll("select.max-select").forEach(s => { s.selectedIndex = s.options.length - 1 })
    menu.querySelectorAll(".pop-size-box").forEach(b => b.classList.remove("active"))
    menu.querySelectorAll(".rate-tier-box").forEach(b => b.classList.remove("active"))
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
        case "rate_tier": {
          const activeBtns = Object.keys(RATE_TIER_BTN_MAP).filter(id => document.getElementById(id)?.classList.contains("active"))
          const noInfo = document.getElementById("rate-tier-no-info")?.checked
          const selected = [...activeBtns.map(id => RATE_TIER_BTN_MAP[id]), ...(noInfo ? ["no_information"] : [])]
          if (selected.length > 0) p[f.param] = selected
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
        case "subcat_panel": {
          const parent = document.getElementById(f.parentId)
          if (!parent?.checked && !parent?.indeterminate) break
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
        case "range_select": {
          const minVal = document.getElementById(f.minInputId)?.value
          const maxVal = document.getElementById(f.maxInputId)?.value
          if (minVal && minVal !== f.minSentinel) p[f.param_min] = minVal
          if (maxVal && maxVal !== f.maxSentinel) p[f.param_max] = maxVal
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
        case "rate_tier": {
          if (!params[f.param]) break
          params[f.param].forEach(val => {
            if (val === "no_information") {
              const el = document.getElementById("rate-tier-no-info")
              if (el) el.checked = true
            } else {
              const id = RATE_TIER_ID_MAP[val]
              if (id) document.getElementById(id)?.classList.add("active")
            }
          })
          document.getElementById("subcat-rate-tier")?.classList.remove("hidden")
          this.#setToggleArrow("subcat-rate-tier", true)
          this.#syncRateTierParent()
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
        case "subcat_panel": {
          const anySubcatSet = f.subcats.some(s => params[s.param_min] != null || params[s.param_max] != null)
          if (!anySubcatSet) break

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

          const parent = document.getElementById(f.parentId)
          if (parent) {
            const checkedCount = f.subcats.filter(s => document.getElementById(s.id)?.checked).length
            parent.checked = checkedCount === f.subcats.length
            parent.indeterminate = checkedCount > 0 && checkedCount < f.subcats.length
          }
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
        case "range_select": {
          const minEl = document.getElementById(f.minInputId)
          if (minEl && params[f.param_min] != null) minEl.value = params[f.param_min]
          const maxEl = document.getElementById(f.maxInputId)
          if (maxEl && params[f.param_max] != null) maxEl.value = params[f.param_max]
          break
        }
      }
    }
  }

  #syncToUrl() {
    const url = new URL(window.location)
    const cols = colsFromUrl()
    const { sort, direction } = sortFromUrl()
    const hasFilters = Object.keys(FilterState.get()).length > 0

    url.search = ""
    if (hasFilters || cols !== null) {
      url.searchParams.set("encoded", buildEncodedParam({ filters: FilterState.get(), cols }))
    }
    if (sort) url.searchParams.set("sort", sort)
    if (direction) url.searchParams.set("direction", direction)
    history.replaceState({}, "", url)
  }

  #restoreFromUrl() {
    if (!window.location.search) return

    const sp = new URLSearchParams(window.location.search)
    const encoded = sp.get("encoded")
    if (!encoded) return

    const params = decodeState(encoded).filters ?? {}
    if (Object.keys(params).length === 0) return

    this.#restoreDomState(params)
    this.#loadVisibleSliders()
    FilterState.set(params)
    document.dispatchEvent(new CustomEvent("filters:changed"))
    this.#reloadStatsFrame()
    this.#reloadTableFrame()
  }

  #updateBadges() {
    const p = FilterState.get()

    const countKeys = (keys) => keys.filter(k => p[k] != null && p[k] !== "").length

    const countArrayFilters = (filters, group) =>
      filters.filter(f => f.group === group)
        .reduce((sum, f) => sum + (Array.isArray(p[f.param]) ? p[f.param].length : 0), 0)

    const countMinMaxFilters = (filters, group) =>
      filters.filter(f => f.group === group)
        .reduce((sum, f) => sum + (p[f.param_min] != null || p[f.param_max] != null ? 1 : 0), 0)

    // 1 for the parent + 1 per active subcat row
    const countSubcatPanelFilters = (group) =>
      SUBCAT_PANEL_FILTERS.filter(f => f.group === group)
        .reduce((sum, f) => {
          const activeSubcats = f.subcats.filter(s => p[s.param_min] != null || p[s.param_max] != null)
          return sum + (activeSubcats.length > 0 ? 1 + activeSubcats.length : 0)
        }, 0)

    // 1 for the parent checkbox + 1 per selected tier/option
    const countRateTierFilters = (group) =>
      RATE_TIER_FILTERS.filter(f => f.group === group)
        .reduce((sum, f) => {
          const items = Array.isArray(p[f.param]) ? p[f.param].length : 0
          return sum + (items > 0 ? 1 + items : 0)
        }, 0)

    const countForGroup = (group) =>
      countKeys(GROUP_KEYS[group] || [])
        + countArrayFilters(GROUP_TYPE_FILTERS, group)
        + countArrayFilters(POP_CAT_FILTERS, group)
        + countRateTierFilters(group)
        + countMinMaxFilters(RANGE_FILTERS, group)
        + countMinMaxFilters(RANGE_SELECT_FILTERS, group)
        + countSubcatPanelFilters(group)

    let moreCount = countForGroup(10)

    for (const group of [1, 2, 3, 4, 5]) {
      const li = document.querySelector(`.filter-${group}`)
      const count = countForGroup(group)
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

  #syncTypeLabel(allChecked) {
    const label = document.getElementById("type-deselect-all-txt")
    if (label) label.textContent = allChecked ? "Deselect all" : "Select all"
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

  #loadVisibleSliders() {
    this.element.querySelectorAll("[data-controller~='slider']").forEach(panel => {
      if (!panel.classList.contains("hidden")) this.#loadSlider(panel)
    })
  }
}
