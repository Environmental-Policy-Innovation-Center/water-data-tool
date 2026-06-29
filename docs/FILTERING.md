# Filtering

The map page exposes a multi-level filter system that narrows the set of public water systems shown on the map and in the data table. Filters are collected by `filter_controller.js` on Apply, written to `FilterState`, and dispatched as a `filters:changed` event. `map_controller.js` and the Turbo Frame table listen for that event and re-fetch with the current params. Backend filtering is implemented in the `Filterable` concern on `PublicWaterSystem` (`app/models/concerns/filterable.rb`).

---

## Source of truth (implementation)

Filters are config-driven and split across files by concern. The menu UI is **generated** from config and the JS is **DOM-driven** — there is no hand-maintained client registry.

| Piece | Role |
|--------|------|
| `config/fields.yml` (via `FieldRegistry`) | What each filterable FIELD *is*: `filter.kind`, `param` / `param_base`, `label`, `tooltip`, `options` (value/label/default), `has_select_all`, an optional `control:` widget override (e.g. `range_select`, `pop_cat`, `rate_tier`), and the `histogram:` block that drives its slider. |
| `config/filter_layout.yml` (via `FilterLayout`) | How filters are ARRANGED: which menu/category each sits in, nesting (parent → sub-filters), and **order** (definition order — see [Menu layout & order](#menu-layout--order)). Also owns the copy for menus/categories/parent-filters, which are not fields. |
| `config/filters.yml` (via `FilterRegistry`) | **Legacy / transitional.** After Thread A Stages 1–2 (docs/CONFIG_AUDIT.md), `permit_arguments` + the sortable maps derive from the manifest and `Filterable` is layout-driven; `filters.yml` now only backs the permit/sort **parity spec** and the `client_payload` JSON embed. Slated for deletion in Stage 3. |
| `Filterable` | One generic range combiner (`apply_range_filters`) builds each filter from the manifest (`FieldRegistry`) and ANDs siblings / ORs `sub_filters` per `FilterLayout.parent_of`; direct, rate-tier, and geographic filters stay bespoke. No longer reads `FilterRegistry`. |

**The menu UI is generated, not hand-authored.** `app/views/home/_filter_menus.html.erb` is a ~25-line driver that loops `FilterLayout.menus → categories → filters` and renders one `_filter_*` partial per control kind; the tab bar in `index.html.erb` loops the same `FilterLayout.menus`. The generated markup emits a **`data-filter-*` DOM contract** (below) rather than hand-matched element ids.

**The JS is DOM-driven.** `filter_controller.js` has **no `FILTERS` registry and no hardcoded ids**. On Apply it collects state by walking `[data-filter-kind]` and reading the contract; badge counts, Reset, and the subcat/rate-tier/select-all toggles work the same way. The server renders the active filter state into the DOM on load, so there is no `restoreDomState` either.

### The `data-filter-*` contract

Each control's root carries `data-filter-kind` (`radio` · `bool` · `multiselect` · `pop_cat` · `rate_tier` · `place` · `range` · `range_select` · `subcat_parent`) and `data-filter-group` (the menu `id`, used for badge counting). Options carry `data-filter-value` (+ `data-filter-param`). A `range` reuses the slider's `data-slider-field-value` (the param base → `<base>_min` / `<base>_max`) and its `data-slider-target` min/max inputs; `range_select` carries `data-filter-param-min/max` + `data-filter-min/max-sentinel`; `place` carries `data-filter-param` + `data-filter-name-param`. `filter_controller.js` is the single reader of this contract.

**Map page embed:** `app/views/home/_filter_registry_config.html.erb` still renders `<script type="application/json" id="filter-registry-config">` with `FilterRegistry.client_payload_json` — a browser-visible copy of the *backend* permit/column contract for dev-tools inspection. The DOM-driven `filter_controller.js` does not consume it.

**Checklist when adding a filter:** add the field's `filter:` block to `config/fields.yml` → place it in `config/filter_layout.yml` (the menu/category + order; nest it under a parent's `sub_filters` to OR it with siblings, or list it as a plain sibling to AND it) → for a histogram slider, add the manifest `histogram:` block → add/extend specs. **No JS, no ERB id edits, and no `filters.yml` / `Filterable` changes** — the range combiner is generic, and the menu markup + collect/restore/badge logic are generated and DOM-driven.

### Menu layout & order

Menus, categories, and filters render in **definition order** from `config/filter_layout.yml`: the tab bar, the dropdown panels, and the More-overflow placeholders all loop `FilterLayout.menus`, so moving a block in the YAML reorders the UI. Each menu's integer `id` is a stable DOM/badge/JS handle (More = `10`) and does **not** affect order. A menu may also set `mobile_label`, `width`, and (for the More panel) `more_menu` / `reset_action` / `reset_label`. `spec/requests/home_spec.rb` asserts the tabs render in layout order. (The responsive collapse breakpoints in `filter_layout_controller.js` still reference menus by `id`; adding a menu needs a breakpoint entry there.)

---

## Table Search

Table search is a separate mechanism from the faceted filter system — it is **not** a `Filterable` filter, not in `FilterRegistry`, and has no `data-filter-*` control collected by `filter_controller.js`. It runs as a post-filter `ILIKE` query via `Sortable#apply_search` after `apply_filters` has already narrowed the scope.

**State:** The search term lives in `SearchState` (a separate singleton from `FilterState`) and is encoded into `?encoded=` as a top-level `"search"` key alongside `"filters"` and `"cols"`. `HomeController#table` reads it from `decoded_state["search"]` independently of `filter_params`.

**Scope:** Searches across `pws_name`, `pwsid`, `stusps`, and `counties` using case-insensitive `ILIKE`. Applied to the already-filtered scope — search narrows within whatever the faceted filters return, not the full dataset. Zero results is expected and correct when search and geographic filters conflict; the search input itself (with the browser's native × clear) is the primary visual affordance. The table `<caption>` also describes the active search term but is `sr-only` (screen readers only).

**Lifecycle:** Written to `SearchState` on debounce (300ms, 2-character minimum). Unaffected by filter Apply (lives outside `FilterState`). Cleared by Reset All (`filter:reset-all` event). Does not affect the map endpoint.

**What it is not:** Unlike the "Place" filter (Source menu), which filters by a census place geoid and affects both map and table, the search term only affects the table. It is not a faceted dimension and carries no badge count.

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

- A **Menu** is one of the main topic tabs (Source, Attributes, Boundaries, Compliance, Population, More); the set of tabs and their order come from `config/filter_layout.yml`.
- A **Category** is a named section within a menu that groups related options. Categories are headers — they have no filter params of their own.
- A **Group** is a toggleable filter option within a category. Turning it on narrows results. Some groups reveal sub-filters when enabled.
- A **Sub-filter** is a more specific option nested under a group.
- A **Range** is a histogram slider attached to a group or sub-filter. Intermediate levels are optional — a Group can attach a Range directly with no Sub-filter in between.

Nested **group → sub-filters → ranges** UIs (Compliance health 5yr/10yr and **More → Watershed hazards**) render as a `data-filter-kind="subcat_parent"` row wrapping nested `data-filter-kind="range"` rows; `filter_controller.js` handles the parent check-all / indeterminate state generically off that contract. The naming is domain-neutral; backend params still map to `violations_summaries` columns vs `watershed_hazards` via `Filterable` / `config/filters.yml`.

---

## Filter Logic

### Faceted search model

**The rule, in one line: every filter ANDs; the only OR is among `sub_filters` of a shared parent.**
Combination is read straight off `config/filter_layout.yml` structure by `Filterable` (via
`FilterLayout.parent_of`) — categories and menus are visual only and do **not** affect AND/OR.

| Boundary | Logic | Example |
|---|---|---|
| Between any two `filters:` entries (same or different category/menu) | AND | Source AND Compliance; Health 5yr AND Non-health both required |
| Between `sub_filters:` within one parent | OR | Groundwater rule OR Lead & copper satisfies Health 5yr |
| Between range bounds (within one filter) | AND | `col >= min AND col <= max` |
| Among a multiselect's selected values (within one filter) | OR | owner = Federal OR Local |

To make a set of filters **OR**, nest them under a parent with `sub_filters`; to **AND** them, list them
as siblings. Adding a sub-filter to a parent therefore broadens; adding a sibling filter narrows.

---

## Trend metrics: which column we filter on (`*_capped`)

**Population change** and **Median household income change** on the map are range filters. The user’s lower and upper bounds are sent as URL params ending in `_min` and `_max` (those suffixes are **not** database columns—they are only the request keys for the two numbers).

**What we query in SQL:** `Filterable` compares the user’s bounds only to `trend_data.population_pct_change_capped` and `trend_data.mhi_pct_change_capped`. We do **not** filter on the raw columns.

**Why cap:** Raw percent changes can explode when the 2011 baseline is tiny (e.g. a military installation going from a handful of connections to thousands). That produces meaningless percentages for mapping and makes histograms collapse into a single bin. ETL stores **capped** values (typically clipped to a band such as ±200%) so filters, sliders, and histograms stay on a human scale. See [frontend_refactor/HISTOGRAMS.md](./frontend_refactor/HISTOGRAMS.md).

**Why we still store raw:** `population_pct_change` and `mhi_pct_change` keep the **true** calculated change for exports, API payloads, and completeness. They are not used for map filtering.

**Example (large raw vs capped):** `PublicWaterSystem` **Ft Wainwright - Main Post** (`pwsid` **AK2310918**) — `population_pct_change` **+555,500%** (artifact of a small baseline), `population_pct_change_capped` **+200%** (capped for display and filtering). Map logic uses **+200%** when deciding if the system passes a population-change range filter.

**URL shape:** Params mirror the filtered column name, e.g. `population_pct_change_capped_min` / `population_pct_change_capped_max` (bounds applied to `population_pct_change_capped`).

---

## Filter Tree

**Legend:**

- *(no marker)* — implemented
- `⚠️` — partially implemented; issue noted inline
- `🚫` — disabled in UI (may still be permitted/filterable on the server)
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
  - Service area in square miles *(Group, range_select — min/max pair counts as 1)*

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
  - Boil water notices 🚫 *(Map UI is a disabled placeholder only—it carries no `data-filter-kind`, so `filter_controller.js` never collects it and Apply does not send params. The server already permits and applies `boil_water_notices_min` / `max` via `boil_water_summaries` (`config/filters.yml`, `Filterable`). The legacy app enabled this filter only for selected geographies because BWN coverage was treated as incomplete; that Stimulus behavior is not re‑implemented yet.)*

---

### Population *(Menu)*

- **Size** *(Category)*
  - Population category — Very small / Small / Medium / Large / Very large *(Group, button set)*
  - > ⚠️ When this category overflows into the More menu, the header reads "Size" rather than "Population size". The legacy app toggled two `<h3>` elements via CSS (`visible-in-main` / `visible-in-more`). Not yet fixed.
- **Density** *(Category)*
  - People per square mile *(Group, range_select — min/max pair counts as 1)*
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

### Range params: min and max

**Intended behavior:** An applied histogram range is a **closed interval**: both `{field}_min` and `{field}_max` should appear in the request so SQL matches what the slider shows.

**How the UI gets there:** Each histogram uses `slider_controller.js`. For health subcat sliders, when the sub-row panel is opened `filter_controller.js` calls `populateDefaultsIfEmpty()`, which writes **domain_min** and **domain_max** to the hidden inputs if they are still empty (handles the race where the panel opens before the histogram fetch resolves — a `#needsDefaults` flag defers the write until `#init` runs). After a drag, `#onUp` writes **both** values from the current handle positions. So in normal use—histogram fetched, panel visible, user Apply—**both keys are sent** for each active range row.

**Collection:** `filter_controller.js` still does `if (minVal)` / `if (maxVal)` when building params, so an input that is literally empty omits that key. That matters only in edge cases: e.g. Apply before the histogram request has finished (inputs not yet filled), a bookmark/URL that restored only one bound, or right after `resetToFullRange()` which clears inputs to `""` until defaults run again. **`Filterable`** applies each present bound separately; there is no server-side guard that both must exist together.

### Badge counting rule

Badge counts are driven entirely by `FilterState` (the applied URL params snapshot) — never by DOM checkbox state. Counts only update on Apply, which is when FilterState is written. This eliminates any divergence between the displayed count and what was actually last applied.

Rules per filter type:

| Type | Counting rule |
|------|---------------|
| `bool` / `radio` / `place` | +1 per set param |
| `group` (`owner_type`, `primacy_type`, `most_common_rate_tier`) | +1 per individually selected option; all selected (default) or none = 0 |
| `pop_cat` | +1 per selected population size category |
| `range` (histograms) | +1 per active parent row, regardless of where min/max handles land |
| `range_select` (area, density) | +1 for the pair if either or both ends are non-sentinel |
| `subcat_panel` (health violations, watershed hazards) | +1 for the parent + +1 per active sub-row; parent with 3 active sub-filters = 4 |

Badge counting is DOM-driven (`filter_controller.js` reads each control's `data-filter-kind` / `data-filter-group`), so a new filter of any of these kinds counts correctly with no JS change.

### Rate tiers as array params

`most_common_rate_tier` is permitted as an array param (`most_common_rate_tier[]` in URL). This allows multi-select — users can narrow to a subset of tiers. The six tiers map to stored string values in the `demographics` table.

### "No rate info" as a standard Group

The "No rate info available" toggle within the Financial section is treated as a boolean Group (Option A), not a new taxonomy term. It expands results rather than narrowing them (includes systems with null rate tier data), but this distinction lives in the backend logic — it does not require a new taxonomy level. A code comment in `filterable.rb` notes that this param expands rather than narrows.

### AND/OR is structural (filters AND, sub_filters OR)

Combination is derived from the layout, not hardcoded per model. Funding's three columns are sibling
`filters:`, so they **AND** — a system must satisfy every active funding constraint. Watershed hazard
columns are `sub_filters` under one parent, so they **OR** — any matching hazard qualifies. To change
either, change the layout nesting (no code change).

### Health violation sub-categories and violation ranges

- **Within one parent (Health 5yr, or Health 10yr):** checked `sub_filters` OR together — a system matches
  if any selected sub-category's range is satisfied (one disjunct per parent).
- **Across the Violations category's sibling filters** — Health 5yr, Health 10yr, Non-health 5yr, Non-health
  10yr, and the "Open violations" boolean — each is its own `filters:` entry, so they **AND**: a system must
  satisfy every active one.

---

## TODO

- **Filter Counter badges** — counting logic is fully implemented and FilterState-based (see Badge counting rule above). Visual presentation and exact design expectations still need confirmation against final design mockups.
- **Missing tooltips** — `ⓘ` tooltips are missing on several headline category labels: Primary type, Type, Violations, and the Wholesaler filter. Keys need to be added to `config/tooltips.yml` and tooltip spans added to the corresponding ERB.
- **Annual water/sewer bill "no rate info" behavior** — the checkbox is implemented, but expected behavior needs product confirmation: does checking "No rate info" show *only* systems with no rate data, or does it show all currently-filtered systems *plus* those with no rate data? Currently implemented as the latter (expands).
- **Client consumption of `#filter-registry-config`** — optional next step: parse the embed in `filter_controller.js` to cross-check that the `data-filter-*` param keys match the backend permit contract in `config/filters.yml`.
- **URL length** — with many active filters, URLs can become very long. A param compression or alias strategy may be needed. A mapping approach was tried previously and reverted due to complexity; revisit when URLs become a practical problem.

