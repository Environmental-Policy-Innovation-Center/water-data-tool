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

- A **Menu** is one of the main topic tabs — Source, Attributes, Boundaries, Compliance, Population, More.
- A **Category** is a named section within a menu that groups related options. Categories are headers — they have no filter params of their own.
- A **Group** is a toggleable filter option within a category. Turning it on narrows results. Some groups reveal sub-filters when enabled.
- A **Sub-filter** is a more specific option nested under a group.
- A **Range** is a histogram slider attached to a group or sub-filter. Intermediate levels are optional — a Group can attach a Range directly with no Sub-filter in between.

---

## Filter Logic

### Faceted search model

| Boundary | Logic | Example |
|---|---|---|
| Between menus | AND | Source AND Compliance both satisfied |
| Between categories within a menu | AND | Violations AND Notices both satisfied |
| Between groups within a category | OR | Health 5yr OR Non-health 5yr satisfies Violations |
| Between sub-filters within a group | OR | Groundwater rule OR Lead & copper satisfies Health 5yr |
| Between range bounds | AND | `col >= min AND col <= max` |
| Between time windows (5yr vs 10yr) | OR | A system with qualifying violations in either window is included |

Enabling more groups within a category **broadens** results (OR). Enabling filters across different categories **narrows** results (AND).

---

## Filter Tree

**Legend:**
- *(no marker)* — implemented
- `⚠️` — partially implemented; issue noted inline
- `🚫` — disabled (data unavailable)
- `~ range` — has a histogram range slider attached

> All groups and sub-filters have a `ⓘ` tooltip. Tooltip copy lives in `config/tooltips.yml`, sourced from the legacy app's `deprecated/assets/js/tooltips.js` where applicable.

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
  - Health violations in the last 10 years *(Group, parent toggle)* — same 10 sub-filters as 5yr
  - Non-health violations in the last 5 years *(Group)* ~ range
  - Non-health violations in the last 10 years *(Group)* ~ range
- **Notices** *(Category)*
  - Boil water notices 🚫 *(Group — data unavailable)*

---

### Population *(Menu)*

- **Size** *(Category)*
  - Population category — Very small / Small / Medium / Large / Very large *(Group, button set)*
  - > ⚠️ When this category overflows into the More menu, the header reads "Size" rather than "Population size". The legacy app toggled two `<h3>` elements via CSS (`visible-in-main` / `visible-in-more`). Not yet fixed.
- **Density** *(Category)*
  - People per square mile *(Group, select min/max)*
- **Change** *(Category)*
  - Population change (10 years) *(Group)* ~ range (% change, signed)
  - Median household income change (10 years) *(Group)* ~ range (% change, signed)
- **Socioeconomics** *(Category)*
  - Households below the poverty line *(Group)* ~ range (%)
  - Unemployment *(Group)* ~ range (%)
  - Annual median household income *(Group)* ~ range ($)
  - Higher education attainment *(Group)* ~ range (%)
  - Children under 5 *(Group)* ~ range (%)
  - Elderly over 61 *(Group)* ~ range (%)
- **Race/Ethnicity** *(Category)*
  - People of color *(Group)* ~ range (%)
  - White *(Group)* ~ range (%)
  - Black *(Group)* ~ range (%)
  - American Indian and Alaskan Native *(Group)* ~ range (%)
  - Native Hawaiian and Pacific Islanders *(Group)* ~ range (%)
  - Asian *(Group)* ~ range (%)
  - Latino/a *(Group)* ~ range (%)
  - Other *(Group)* ~ range (%)
  - Mixed race *(Group)* ~ range (%)
- **Vulnerability** *(Category)*
  - Disadvantaged area (CEJST) *(Group)* ~ range (%)
  - Social Vulnerability Index *(Group)* ~ range (percentile)
  - Climate Vulnerability Index *(Group)* ~ range (percentile)

---

### More *(Menu)*

> More is a responsive overflow container. When the viewport narrows, other menus' categories collapse into it (Population → Compliance → Boundaries → Attributes → Source). The sections below live permanently in More.

- **Financial** *(Category)*
  - Annual water and sewer bill *(Group, multi-checkbox tier)*
    - Six tier options: Under $125 / $125–249 / $250–499 / $500–749 / $750–999 / Over $1,000
    - No rate info available *(boolean toggle — expands results to include systems with null rate data)*
- **Funding (2021–2025)** *(Category)*
  - State revolving fund financing *(Group)* ~ range (number of times received)
  - State revolving fund assistance *(Group)* ~ range (amount in $)
  - State revolving fund principal forgiveness *(Group)* ~ range (amount in $)
- **Environmental** *(Category)*
  - Potential Watershed Hazards *(Group, parent toggle)*
    - Source water connections *(Sub-filter)* ~ range (number of locations)
    - Pollution permits with breaches *(Sub-filter)* ~ range (number of breaches)
    - Underground storage tanks *(Sub-filter)* ~ range (number of tanks)
    - Risk management plan facilities *(Sub-filter)* ~ range (number of facilities)
    - Streams with impaired or threatened surface waters *(Sub-filter)* ~ range (number of streams)

---

## Key Decisions

### Full column names in URL params

URL params use full DB column names (e.g. `groundwater_rule_5yr_min=3`). A short-alias approach was explored and reverted — aliases added complexity with no clear long-term URL strategy, and full names are self-documenting in the URL.

### Range params always send both min and max

When a range Group is active, both `{field}_min` and `{field}_max` are always sent. Sliders always have domain values from the histogram fetch, so there is never a case where only one bound is present. This simplifies backend filtering — `filterable.rb` always has both values to work with.

### Badge counting rule

Every checked checkbox counts as +1. Parent and child checkboxes are counted independently. If a parent is checked and three of its sub-filters are checked, the badge shows 4. `filter_controller.js` counts range-type filters by DOM checkbox state (not by param presence) to stay consistent with this rule.

### Rate tiers as array params

`most_common_rate_tier` is permitted as an array param (`most_common_rate_tier[]` in URL). This allows multi-select — users can narrow to a subset of tiers. The six tiers map to stored string values in the `demographics` table.

### "No rate info" as a standard Group

The "No rate info available" toggle within the Financial section is treated as a boolean Group (Option A), not a new taxonomy term. It expands results rather than narrowing them (includes systems with null rate tier data), but this distinction lives in the backend logic — it does not require a new taxonomy level. A code comment in `filterable.rb` notes that this param expands rather than narrows.

### OR logic within categories, AND between

Active groups within the Funding category OR together — a system qualifies if it has received *any* form of SRF assistance, not all three. Active watershed hazard sub-filters also OR — a system with any matching hazard qualifies. Both were previously AND (incorrect); fixed in `filterable.rb` using Arel.

### Health violation sub-categories

Within a time window (5yr or 10yr), active sub-categories OR: a system with qualifying violations in any checked category matches. Between time windows, AND: a system must satisfy both the 5yr and 10yr conditions if both parent groups are checked.

---

## TODO

- **Filter Counter badges** — badge counts are wired and increment per the rule above (each checked box = 1), but the visual presentation and exact design expectations need confirmation against final design mockups.

- **Missing tooltips** — `ⓘ` tooltips are missing on several headline category labels: Primary type, Type, Violations, and the Wholesaler filter. Keys need to be added to `config/tooltips.yml` and tooltip spans added to the corresponding ERB.

- **Annual water/sewer bill "no rate info" behavior** — the checkbox is implemented, but expected behavior needs product confirmation: does checking "No rate info" show *only* systems with no rate data, or does it show all currently-filtered systems *plus* those with no rate data? Currently implemented as the latter (expands).

- **Filterable refactoring** — `filterable.rb` has grown significantly. Several patterns (range filter blocks, Arel OR construction, join management) repeat across demographic, EJ, trend, funding, and hazard sections and could be consolidated into shared helpers.

- **URL length** — with many active filters, URLs can become very long. A param compression or alias strategy may be needed. A mapping approach was tried previously and reverted due to complexity; revisit when URLs become a practical problem.
