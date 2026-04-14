import { Controller } from "@hotwired/stimulus"
import * as FilterState from "filter_state"

function buildColumns() {
  const fmt = (thousands, decimal, precision, prefix = "", postfix = "") =>
    window.DataTable.render.number(thousands, decimal, precision, prefix, postfix)

  return [
    // --- Core identity (0–3) ---
    { data: "pws_name", title: "Utility Name", className: "first-col" },
    { data: "pwsid", title: "Utility ID" },
    {
      data: "detailed_facility_report",
      title: "EPA Facility Report",
      orderable: false,
      searchable: false,
      render: (data) => data ? `<a href="${data}" target="_blank" rel="noopener noreferrer">report</a>` : ""
    },
    { data: "stusps", title: "State" },
    // --- Geography & system type (4–13) ---
    { data: "counties", title: "County" },
    { data: "gw_sw_code", title: "Source type" },
    { data: "source_water_protection_code", title: "Source protection" },
    { data: "owner_type", title: "Ownership" },
    { data: "primacy_type", title: "Authority" },
    { data: "is_wholesaler", title: "Wholesaler" },
    { data: "is_school_or_daycare", title: "Facility type (School or daycare)" },
    { data: "symbology_field", title: "Boundary type" },
    { data: "area_sq_miles", title: "Size (Area in square miles)", render: fmt(",", ".", 2) },
    { data: "open_health_viol", title: "Open violations" },
    // --- Violations 5yr (14–24) ---
    { data: "health_violations_5yr", title: "Health violations in the last 5 years", render: fmt(",") },
    { data: "groundwater_rule_5yr", title: "Ground water rule violations in the last 5 years", render: fmt(",") },
    { data: "surface_water_treatment_5yr", title: "Surface water treatment rules violations in the last 5 years", render: fmt(",") },
    { data: "lead_and_copper_5yr", title: "Lead & copper violations in the last 5 years", render: fmt(",") },
    { data: "radionuclides_5yr", title: "Radionuclides violations in the last 5 years", render: fmt(",") },
    { data: "inorganic_chemicals_5yr", title: "Inorganic chemicals violations in the last 5 years", render: fmt(",") },
    { data: "synthetic_organic_chemicals_5yr", title: "Synthetic organic chemicals violations in the last 5 years", render: fmt(",") },
    { data: "volatile_organic_chemicals_5yr", title: "Volatile organic chemicals violations in the last 5 years", render: fmt(",") },
    { data: "total_coliform_5yr", title: "Coliform violations in the last 5 years", render: fmt(",") },
    { data: "stage_1_disinfectants_5yr", title: "Stage 1 disinfectants violations in the last 5 years", render: fmt(",") },
    { data: "stage_2_disinfectants_5yr", title: "Stage 2 disinfectants violations in the last 5 years", render: fmt(",") },
    // --- Violations 10yr (25–35) ---
    { data: "health_violations_10yr", title: "Health violations in the last 10 years", render: fmt(",") },
    { data: "groundwater_rule_10yr", title: "Ground water rule violations in the last 10 years", render: fmt(",") },
    { data: "surface_water_treatment_10yr", title: "Surface water treatment rules violations in the last 10 years", render: fmt(",") },
    { data: "lead_and_copper_10yr", title: "Lead & copper violations in the last 10 years", render: fmt(",") },
    { data: "radionuclides_10yr", title: "Radionuclides violations in the last 10 years", render: fmt(",") },
    { data: "inorganic_chemicals_10yr", title: "Inorganic chemicals violations in the last 10 years", render: fmt(",") },
    { data: "synthetic_organic_chemicals_10yr", title: "Synthetic organic chemicals violations in the last 10 years", render: fmt(",") },
    { data: "volatile_organic_chemicals_10yr", title: "Volatile organic chemicals violations in the last 10 years", render: fmt(",") },
    { data: "total_coliform_10yr", title: "Coliform violations in the last 10 years", render: fmt(",") },
    { data: "stage_1_disinfectants_10yr", title: "Stage 1 disinfectants violations in the last 10 years", render: fmt(",") },
    { data: "stage_2_disinfectants_10yr", title: "Stage 2 disinfectants violations in the last 10 years", render: fmt(",") },
    // --- Non-health violations (36–37) ---
    { data: "paperwork_violations_5yr", title: "Non-health violations in the last 5 years", render: fmt(",") },
    { data: "paperwork_violations_10yr", title: "Non-health violations in the last 10 years", render: fmt(",") },
    // --- Boil water (38) ---
    { data: "total_notices", title: "Boil water notices", render: fmt(",") },
    // --- Demographics (39–57) ---
    { data: "total_population", title: "Population size", render: fmt(",") },
    { data: "population_density", title: "Population density (people per square mile)", render: fmt(",", ".", 0) },
    { data: "poverty_rate", title: "Households below the poverty line (%)", render: fmt(",", ".", 2, "", "%") },
    { data: "unemployment_rate", title: "Unemployment (%)", render: fmt(",", ".", 2, "", "%") },
    { data: "median_household_income", title: "Annual median household income ($)", render: fmt(",", ".", 0, "$") },
    { data: "bachelors_degree_rate", title: "Higher education attainment (%)", render: fmt(",", ".", 2, "", "%") },
    { data: "age_under_5_rate", title: "Children under 5 (%)", render: fmt(",", ".", 2, "", "%") },
    { data: "age_over_61_rate", title: "Elderly over 61 (%)", render: fmt(",", ".", 2, "", "%") },
    { data: "poc_rate", title: "People of color (%)", render: fmt(",", ".", 2, "", "%") },
    { data: "white_rate", title: "White (%)", render: fmt(",", ".", 2, "", "%") },
    { data: "black_rate", title: "Black (%)", render: fmt(",", ".", 2, "", "%") },
    { data: "aian_rate", title: "American Indian and Alaskan Native (%)", render: fmt(",", ".", 2, "", "%") },
    { data: "napi_rate", title: "Native Hawaiian and Pacific Islanders (%)", render: fmt(",", ".", 2, "", "%") },
    { data: "asian_rate", title: "Asian (%)", render: fmt(",", ".", 2, "", "%") },
    { data: "hispanic_rate", title: "Latino/a (%)", render: fmt(",", ".", 2, "", "%") },
    { data: "other_race_rate", title: "Other (%)", render: fmt(",", ".", 2, "", "%") },
    { data: "mixed_race_rate", title: "Mixed race (%)", render: fmt(",", ".", 2, "", "%") },
    { data: "most_common_rate_tier", title: "Annual water and sewer bill" },
    // --- Environmental justice (58–60) ---
    { data: "cejst_disadvantaged_pct", title: "Disadvantaged area (%)", render: fmt(",", ".", 2, "", "%") },
    { data: "svi_overall_pctl", title: "Social Vulnerability Index (%)", render: fmt(",", ".", 2, "", "%") },
    { data: "cvi_overall_score", title: "Climate Vulnerability Index (%)", render: fmt(",", ".", 2, "", "%") },
    // --- Funding (61–63) ---
    { data: "times_funded", title: "State revolving fund financing (2021–2025) — times received", render: fmt(",") },
    { data: "total_srf_assistance", title: "State revolving fund assistance (2021–2025) — amount received ($)", render: fmt(",", ".", 2, "$") },
    { data: "total_principal_forgiveness", title: "State revolving fund principal forgiveness (2021–2025) — amount forgiven ($)", render: fmt(",", ".", 2, "$") },
    // --- Watershed hazards (64–68) ---
    { data: "num_facilities", title: "Source water connections", render: fmt(",") },
    { data: "permit_effluent_violations", title: "Pollution permits with breaches", render: fmt(",") },
    { data: "open_underground_storage_tanks", title: "Underground storage tanks", render: fmt(",") },
    { data: "risk_management_plan_facilities", title: "Risk management plan facilities", render: fmt(",") },
    { data: "impaired_streams_303d", title: "Streams with impaired or threatened surface waters", render: fmt(",") }
  ]
}

export default class extends Controller {
  #dataTable = null

  connect() {
    document.addEventListener("table:show", this.#onTableShow)
    document.addEventListener("filters:changed", this.#onFiltersChanged)
  }

  disconnect() {
    document.removeEventListener("table:show", this.#onTableShow)
    document.removeEventListener("filters:changed", this.#onFiltersChanged)
    this.#dataTable?.destroy()
    this.#dataTable = null
  }

  #onTableShow = () => {
    if (!this.#dataTable) {
      this.#init()
    }
  }

  #onFiltersChanged = () => {
    // false = preserve current page position on reload
    this.#dataTable?.ajax.reload(null, false)
  }

  #init() {
    this.#dataTable = new window.DataTable("#data-table", {
      serverSide: true,
      ajax: {
        url: "/table.json",
        type: "GET",
        // Strip verbose per-column params — server only needs draw/start/length/search/order/filters
        data: (d) => ({
          draw: d.draw,
          start: d.start,
          length: d.length,
          "search[value]": d.search.value,
          "order[0][column]": d.order[0]?.column,
          "order[0][dir]": d.order[0]?.dir,
          ...FilterState.get()
        })
      },
      columns: buildColumns(),
      lengthChange: false,
      pageLength: 100,
      searching: true,
      processing: true,
      scrollX: true,
      scrollY: "calc(100vh - 260px)",
      scrollCollapse: true,
      columnDefs: [{ className: "first-col", targets: [0] }],
      layout: {
        topStart: { search: { placeholder: "Search table...", text: "" } },
        topEnd: null,
        bottomStart: { info: {}, paging: { buttons: 5 } },
        bottomEnd: null
      }
    })
  }
}
