# Filtering

The map page exposes a multi-level filter system that narrows the set of public water systems shown on the map and in the data table. All filters are collected by `filter_controller.js` on Apply, written to `FilterState`, and dispatched as a `filters:changed` event. `map_controller.js` and the Turbo Frame table both listen for that event and re-fetch with the current params. Backend filtering is handled entirely by the `Filterable` concern (`app/models/concerns/filterable.rb`).

---

## Taxonomy

Five levels describe every filter option in the system. Use these terms consistently in code, comments, and documentation.

| Level | Term | Example |
|---|---|---|
| 1 | **Menu** | Compliance |
| 2 | **Category** | Violations |
| 3 | **Group** | Health violations (5yr) |
| 4 | **Sub-filter** | Ground water rule |
| 5 | **Range** | Histogram slider min / max |

- A **Menu** is one of the main topic tabs across the top of the map — Source, Attributes, Boundaries, Compliance, Population, and More. Clicking a tab opens a dropdown with all the options for that topic.
- A **Category** is a named section within a menu that groups related options together. For example, the Compliance menu contains a Violations category and a Notices category.
- A **Group** is a filter option within a category. Turning a group on narrows results to systems that match that criterion. Some groups reveal sub-filters when enabled.
- A **Sub-filter** is a more specific option nested under a group, letting users drill down further. For example, the Health violations group reveals ten sub-filters — one per violation type.
- A **Range** is a histogram slider attached to a group or sub-filter that lets users narrow results to a specific numeric range (e.g., number of violations, percentage of population, dollar amount).

---

## Filter Logic

### Implemented behavior (faceted search model)

| Boundary | Logic | Example |
|---|---|---|
| Between menus | AND | Source AND Compliance must both be satisfied |
| Between categories within a menu | AND | Violations AND Notices must both be satisfied |
| Between groups within a category | OR | Health 5yr OR Non-health 5yr satisfies Violations |
| Between sub-filters within a group | OR | Groundwater rule OR Lead & copper satisfies Health 5yr |
| Between range bounds (min/max) | AND | `col >= min AND col <= max` |
| Between time windows (5yr vs 10yr) | OR | A system with qualifying violations in either window is included |

Enabling more groups within a category **broadens** results (inclusive / OR). Enabling filters across different categories **narrows** results (AND). This is the standard faceted-search model.

---

## Filter Tree

**Legend:**
- No marker — implemented
- `⚠️` — partially implemented (UI exists; needs range histogram, parent group, or other work noted inline)
- `🔲` — not yet built
- `🚫` — disabled (data unavailable or TBD)
- `~ range` — has a range histogram attached

> All groups and sub-filters should have a tooltip (ⓘ icon). The legacy app had tooltips on nearly every item. Tooltip copy should be sourced from `deprecated/assets/js/tooltips.js` and migrated to `config/tooltips.yml`.

---

### Source *(Menu)*

- **Primary type** *(Category)*
  - Water source type — Ground only / Surface only / Both *(Group, radio)*
- **Place** *(Category)*
  - City or town search *(Group, place autocomplete)*
- **Protection** *(Category)*
  - Has source water protection *(Group, bool)*

---

### Attributes *(Menu)*

- **Ownership** *(Category)*
  - Owner type — Federal / State / Local / Tribal / Private / Public–Private *(Group, multi-checkbox)*
- **Authority** *(Category)*
  - Primacy type — State / Tribal / Territory *(Group, multi-checkbox)*
- **Distribution** *(Category)*
  - Wholesaler *(Group, bool)*
- **Facility type** *(Category)*
  - School or daycare *(Group, bool)*

---

### Boundaries *(Menu)*

- **Type** *(Category)*
  - Boundary type — Modeled only / System sourced only / Both *(Group, radio)*
- **Size** *(Category)*
  - Service area in square miles *(Group, select min/max)*

---

### Compliance *(Menu)*

- **Violations** *(Category)*
  - Open violations *(Group, bool)*
  - Health violations in the last 5 years *(Group, parent toggle)*
    - Ground water rule *(Sub-filter)* ~ range
    - Surface water treatment rules *(Sub-filter)* ~ range
    - Lead & copper *(Sub-filter)* ~ range
    - Radionuclides *(Sub-filter)* ~ range
    - Inorganic chemicals *(Sub-filter)* ~ range
    - Synthetic organic chemicals *(Sub-filter)* ~ range
    - Volatile organic chemicals *(Sub-filter)* ~ range
    - Coliform *(Sub-filter)* ~ range
    - Stage 1 disinfectants *(Sub-filter)* ~ range
    - Stage 2 disinfectants *(Sub-filter)* ~ range
  - Health violations in the last 10 years *(Group, parent toggle)*
    - Ground water rule *(Sub-filter)* ~ range
    - Surface water treatment rules *(Sub-filter)* ~ range
    - Lead & copper *(Sub-filter)* ~ range
    - Radionuclides *(Sub-filter)* ~ range
    - Inorganic chemicals *(Sub-filter)* ~ range
    - Synthetic organic chemicals *(Sub-filter)* ~ range
    - Volatile organic chemicals *(Sub-filter)* ~ range
    - Coliform *(Sub-filter)* ~ range
    - Stage 1 disinfectants *(Sub-filter)* ~ range
    - Stage 2 disinfectants *(Sub-filter)* ~ range
  - Non-health violations in the last 5 years *(Group)* ~ range
  - Non-health violations in the last 10 years *(Group)* ~ range
- **Notices** *(Category)*
  - Boil water notices 🚫 *(Group, bool — data unavailable)* ~ range

---

### Population *(Menu)*

- **Size** *(Category)*
  - Population category — Very small / Small / Medium / Large / Very large *(Group, button set)*
  - > ⚠️ When this category collapses into the More menu, the header should read "Population size" not "Size". Legacy used two `<h3>` elements with CSS toggling on `visible-in-main` / `visible-in-more`.
- **Density** *(Category)*
  - People per square mile *(Group, select min/max)*
- **Change** 🔲 *(Category — not yet built)*
  - Change in people the last 10 years 🔲 *(Group, bool)* ~ range (% change, signed)
  - Change in income the last 10 years 🔲 *(Group, bool)* ~ range (% change, signed)
- **Socioeconomics** 🔲 *(Category — not yet built)*
  - Households below the poverty line 🔲 *(Group, bool)* ~ range (%)
  - Unemployment 🔲 *(Group, bool)* ~ range (%)
  - Annual median household income 🔲 *(Group, bool)* ~ range ($)
  - Higher education attainment 🔲 *(Group, bool)* ~ range (%)
  - Children under 5 🔲 *(Group, bool)* ~ range (%)
  - Elderly over 61 🔲 *(Group, bool)* ~ range (%)
- **Race/Ethnicity** 🔲 *(Category — not yet built)*
  - People of color 🔲 *(Group, bool)* ~ range (%)
  - White 🔲 *(Group, bool)* ~ range (%)
  - Black 🔲 *(Group, bool)* ~ range (%)
  - American Indian and Alaskan Native 🔲 *(Group, bool)* ~ range (%)
  - Native Hawaiian and Pacific Islanders 🔲 *(Group, bool)* ~ range (%)
  - Asian 🔲 *(Group, bool)* ~ range (%)
  - Latino/a 🔲 *(Group, bool)* ~ range (%)
  - Other 🔲 *(Group, bool)* ~ range (%)
  - Mixed race 🔲 *(Group, bool)* ~ range (%)
- **Vulnerability** 🔲 *(Category — not yet built)*
  - Disadvantaged area 🔲 *(Group, bool)* ~ range (%)
  - Social Vulnerability Index 🔲 *(Group, bool)* ~ range (percentile)
  - Climate Vulnerability Index 🔲 *(Group, bool)* ~ range (percentile)

---

### More *(Menu)*

> More is a responsive overflow container. When the viewport narrows, other menus' categories collapse into it in order (Population → Compliance → Boundaries → Attributes → Source). The sections below are items that live permanently in More.

- **Financial** *(Category)*
  - Annual water and sewer bill ⚠️ *(Group — currently shows as a disabled checkbox labeled TBD; legacy used a button-set UI with 7 tiers: Any / <$125 / <$250 / <$500 / <$750 / <$1,000 / >$1,000)*
    - Show systems with no available information on rates 🔲 *(checkbox option within the group — legacy had this as a separate toggle inside the sub-panel)*
- **Funding (2021–2025)** *(Category)*
  - State revolving fund financing ⚠️ *(Group, bool — needs range histogram: number of times received)*
  - State revolving fund assistance ⚠️ *(Group, bool — needs range histogram: amount in $)*
  - State revolving fund principal forgiveness ⚠️ *(Group, bool — needs range histogram: amount in $)*
- **Environmental** *(Category)*
  - Potential Watershed Hazards 🔲 *(Group, parent toggle — missing; legacy had sub-filters nested under this parent)*
    - Source water connections ⚠️ *(Sub-filter, bool — exists as direct item today, needs to move under parent; needs range histogram: number of locations)*
    - Pollution permits with breaches ⚠️ *(Sub-filter, bool — exists as direct item today, needs to move under parent; needs range histogram: number of breaches)*
    - Underground storage tanks ⚠️ *(Sub-filter, bool — exists as direct item today, needs to move under parent; needs range histogram: number of tanks)*
    - Risk management plan facilities ⚠️ *(Sub-filter, bool — exists as direct item today, needs to move under parent; needs range histogram: number of facilities)*
    - Streams with impaired or threatened surface waters ⚠️ *(Sub-filter, bool — exists as direct item today, needs to move under parent; needs range histogram: number of streams)*
  
---

## Open Questions

### 1. More menu — taxonomy of Financial / Funding / Environmental

**Current taxonomy:** More is a Menu; Financial, Funding, and Environmental are Categories within it.

**Question raised:** Should Financial/Funding/Environmental be treated as Groups (with "More" acting as the Category)?

**Assessment:** The current taxonomy appears correct. The test is whether an item produces filter behavior on its own — Categories are organizational headers with no filter params; Groups are toggleable filter options. "Financial" and "Funding" are headers, not toggles. The items within them (Annual water bill, SRF financing, etc.) are the Groups. This matches the Compliance pattern exactly: Violations (Category) → Open violations (Group). More is a Menu like any other; it happens to also receive overflow Categories from other menus at narrow viewports, but its permanent sections follow the same hierarchy.

**Decision needed:** Confirm or reconsider this before building any new More menu UI sections.

---

### 2. "Show systems with no available information on rates"

**Current status:** Documented as a checkbox option nested under the Annual water and sewer bill Group.

**Question raised:** Should this be treated as a boolean Group, a Sub-filter, or does it need a new taxonomy term?

**Assessment:** This item doesn't narrow results — it's an opt-in to *include* systems that would otherwise be excluded (systems with null rate data). It behaves more like an "include-nulls modifier" than a filter. None of the current taxonomy levels (Group, Sub-filter, Range) cleanly describe it. Options:
- Treat it as a boolean Group (simplest, consistent with existing terms)
- Introduce a new term (e.g., **Modifier**) for "include nulls" type toggles that expand rather than narrow results

**Decision needed:** Agree on the term before building the Financial section.

---

### 3. OR logic for Funding groups

**Current behavior:** When multiple Funding groups are active (e.g., SRF financing AND SRF assistance), `filterable.rb` applies AND logic — a system must satisfy all active funding groups simultaneously.

**Intended behavior:** Groups within a Category should OR (inclusive). A system qualifies if it matches any active Funding group.

**Fix needed:** Apply the same OR-across-groups pattern used in the Violations section. Hold until Funding histograms are built and the section is more complete.

---

### 4. OR logic for Watershed Hazard sub-filters

**Current behavior:** The five watershed hazard columns (`num_facilities`, `permit_effluent_violations`, `open_underground_storage_tanks`, `risk_management_plan_facilities`, `impaired_streams_303d`) are chained with AND in `filterable.rb`.

**Intended behavior:** Sub-filters within a Group should OR — a system qualifies if any active sub-filter matches.

**Fix needed:** Apply Arel OR across active hazard sub-filter nodes. Hold until the Potential Watershed Hazards parent Group toggle is built (the sub-filters currently have no UI entry point).

---                                                                 
### 5. Taxonomy — Groups with direct Range controls, and "include nulls" toggles
                                                                                                                          
**Clarification:** Not every Group requires Sub-filters. A Group can attach a Range (histogram slider or selector) directly at Level 5 with no Level 4 in between. Example: Non-health violations 5yr (Group) → histogram slider (Range). This is valid — intermediate levels are optional.                                 
                                                                                                                          
**Open question:** What do we call a checkbox attached to a Group that broadens results rather than narrowing them — specifically, an opt-in to include systems with null/missing data? Example: "Show systems with no available information on rates" under Annual water and sewer bill.                                                                                
                                                                    
**Options:**
- **Option A — Boolean Group:** treat it like any other on/off Group (Wholesaler, School or daycare). No new terminology. The
Group just happens to expand rather than narrow.                                                                          
- **Option B — Modifier:** introduce a new taxonomy term for toggles that change how a Group's filter applies (include nulls,
invert, etc.). More precise; adds a sixth taxonomy level to maintain.                                                     
                                                                                                                          
**Suggestion: Option A**. The expand-vs-narrow distinction is worth a code comment, but doesn't need a new taxonomy level.
Keeps the spec simple and the existing five-level hierarchy intact.