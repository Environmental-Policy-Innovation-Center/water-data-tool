# Compliance Filter: Sub-filters & Histograms

> **Agent handoff doc.** When you complete a task, mark it `Done` in the Status table and add a one-line note under "Session log" describing what was done and what's next.

---

## Coding Rules

### Frontend (all new UI)
- **Stack:** Hotwire (Turbo + Stimulus), Tailwind CSS, Mapbox GL JS v3.
- **No build step** — Importmaps only. No npm packages or bundled JS.
- **Mobile-first responsive** — use Tailwind `md:` / `lg:` prefixes. Must work on desktop.
- **A11y** — semantic HTML, ARIA labels, high contrast.
- **Stimulus only** — no inline `onclick`, no jQuery, no vanilla DOM manipulation outside controllers.
- **No new CSS** in `water_tool.css` — use Tailwind classes. Migrate any legacy classes you touch.
- **No comments** unless the WHY is non-obvious.

### Backend (any new endpoints or model methods)
- **Stack:** Ruby 3.4.7, Rails 8.1, PostgreSQL + PostGIS.
- **TDD mandatory** — Red → Green → Refactor. Run `bin/ci` before completion.
- **Filterable concern** — add new filter params there, not in controllers.
- **Specs required** for Models, Concerns, and Controllers. Use Factories.
- **No N+1 queries** — use `left_joins` or `includes`.
- **Commands:** `bin/dev` (server), `bundle exec rspec` (tests), `bin/rubocop` (lint).

---

## Scope

The Compliance dropdown (menu 4) needs two features from the legacy app that are currently missing:

1. **Sub-filter panels** — revealed when either "Health violations in the last N years" checkbox is checked.
2. **Histogram range sliders** — revealed when either "Non-health violations in the last N years" checkbox is checked.

---

## Design Mocks

All mocks are in `docs/mocks/subfilters_and_histograms/`.

### `subfilter_default.png`
Shows the sub-filter panel for "Health violations in the last 5 years" — the parent checkbox is checked (blue), and all 10 sub-category checkboxes appear indented beneath it, **all pre-checked** (blue). Each label has an `ⓘ` info icon to the right. No histogram under these checkboxes. This is the default state when the parent is first checked.

### `historgram_style_variations.png`
Shows 6 histogram edge-case states for reference:

| State | Description |
|---|---|
| **DEFAULT STATE** | All bars blue. Min label `1` at bottom-left, max label `#` at bottom-right. Two small black circular handles rest on the baseline. |
| **SELECT SLIDER** | User is dragging; a value label (e.g. `1`) floats above the active handle. |
| **SET RANGE** | Bars outside the selected range turn gray; bars inside stay blue. Label above active handle shows current value (e.g. `10`). "Number of violations" category label shown. |
| **SINGLE VALUE OF 1** | When all data is a single value, renders as a flat line with two dot handles. Labels show `1` on both ends. |
| **PERCENT INCREASE AND DECREASE** | -100% to +100% range with `0` midpoint label — applicable for percent-change fields, not violation counts. |
| **LOW VALUES** | Two variants shown — when data clusters near zero, bars are small/flat. Handles still sit at the range extremes. |

Key visual rules from this mock:
- **Bar color:** Brand blue (`#1054A8`) inside range; gray outside range.
- **Handles:** Small filled black circles, sitting on the chart baseline (not tall thumb sliders).
- **Value tooltip:** Floats above the active handle during drag; shows the current bin value.
  - Copy for each tooltip can be found in deprectated `deprecated/assets/js/tooltips.js` file.
  - We may want to start a new pattern in the current app version as where to store this copy. _(in config/ like datasets.yml?)_
- **Category label:** Gray text above the chart (e.g. "Category description" / "Number of violations").
- **No y-axis, no gridlines** in default state (y-axis label "# of utilities" appears only in one detailed variant — omit for initial implementation).
- **Bottom labels:** Only min and max, left and right.

### `histogram_under_subfilter.png`
Shows the histogram as it appears in the actual compliance menu — directly beneath "Non-health violations in the last 5 years" (parent checked). "Number of violations" label above chart. Chart is full-width within the menu panel. Data is heavily right-skewed (spike at low values, long tail). Two black dot handles at the baseline. Min = `1`, max = `1,070` shown as bottom labels.

---

## Current State (Rails App)

`_filter_menus.html.erb` — Compliance menu has 5 plain checkboxes, no sub-panels, no histograms:

| Checkbox ID | `filter_controller.js` param | Filterable column |
|---|---|---|
| `compliance-open-violations` | `has_open_violations` | `public_water_systems.open_health_viol = 'Yes'` |
| `viols-health-5yrs` | `health_violations_5yr_min=1` | `violations_summaries.health_violations_5yr` |
| `viols-health` | `health_violations_10yr_min=1` | `violations_summaries.health_violations_10yr` |
| `viols-paperwork-5yrs` | `paperwork_violations_5yr_min=1` | `violations_summaries.paperwork_violations_5yr` |
| `viols-paperwork` | `paperwork_violations_10yr_min=1` | `violations_summaries.paperwork_violations_10yr` |

**Good news:** `filterable.rb` already supports `_min` / `_max` params for all violation sub-categories — no backend work for Phase 1. The `violations_summary` model has all 20 sub-category columns (10 rule types × 2 time windows).

---

## Legacy Behavior (Source of Truth: `deprecated/inc-map.php`)

### Health violations (5yr and 10yr)

When the parent "Health violations in the last N years" checkbox is checked, a hidden sub-filter panel expands with **10 sub-category checkboxes**. In the legacy app these started unchecked; **our implementation starts them checked** (per the `subfilter_default.png` mock).

**Sub-filter checkboxes — field crosswalk:**

| Label | 5yr DB column | 10yr DB column |
|---|---|---|
| Ground water rule | `groundwater_rule_5yr` | `groundwater_rule_10yr` |
| Surface water treatment rules | `surface_water_treatment_5yr` | `surface_water_treatment_10yr` |
| Lead & copper | `lead_and_copper_5yr` | `lead_and_copper_10yr` |
| Radionuclides | `radionuclides_5yr` | `radionuclides_10yr` |
| Inorganic chemicals | `inorganic_chemicals_5yr` | `inorganic_chemicals_10yr` |
| Synthetic organic chemicals | `synthetic_organic_chemicals_5yr` | `synthetic_organic_chemicals_10yr` |
| Volatile organic chemicals | `volatile_organic_chemicals_5yr` | `volatile_organic_chemicals_10yr` |
| Coliform | `total_coliform_5yr` | `total_coliform_10yr` |
| Stage 1 disinfectants | `stage_1_disinfectants_5yr` | `stage_1_disinfectants_10yr` |
| Stage 2 disinfectants | `stage_2_disinfectants_5yr` | `stage_2_disinfectants_10yr` |

Per-sub-category histograms (which the legacy app had under each sub-checkbox) are implemented in Phase 3 — see Phase 3 section.

### Non-health violations (5yr and 10yr)

No sub-category checkboxes. When the parent is checked, a histogram range slider appears directly beneath it (see `histogram_under_subfilter.png`).

- `viols-paperwork-5yrs` → histogram over `violations_summaries.paperwork_violations_5yr`
- `viols-paperwork` → histogram over `violations_summaries.paperwork_violations_10yr`

---

## Architecture

### Sub-filter toggle (Stimulus) — current state

Already implemented. `filter_controller.js` handles via `toggleSubcat(event)`:
- Parent checkbox checked → reveals subcat panel, checks all subcats
- Parent checkbox unchecked → hides panel, resets all subcats to checked

`FILTERS` entries for the two health groups use `type: "health_subcat"`. `#collectFilters()`, `#restoreDomState()`, and `#resetMenu()` all handle this type.

### Filter param semantics for sub-categories

**Current state (implemented — boolean presence):**
- Parent unchecked → send nothing
- Parent checked, all sub-cats checked → send `health_violations_5yr=true` (aggregate boolean)
- Parent checked, some sub-cats unchecked → send `{column}=true` for each checked sub-cat only
- Backend: aggregate params → `WHERE col >= 1`; individual subcat params → OR across checked columns within window

**Phase 3 (done — range min/max):**
- Parent checkbox is **UI-only** — sends no params, has no backend handling
- Each checked subcat always sends both `{column}_min=N` and `{column}_max=M` using the full DB column name
- Slider always has values (fetched from histogram endpoint on connect), so both params are always present
- Aggregate params (`health_violations_5yr`, `health_violations_10yr`) removed from `filterable.rb`
- OR logic within a time window: `WHERE (col_a >= min AND col_a <= max) OR (col_b >= min AND col_b <= max) ...`
- AND logic between time windows (5yr vs 10yr) unchanged
- URL params use full DB column names (e.g. `groundwater_rule_5yr_min=3`). A short-alias approach was explored and reverted — aliases added complexity without a clear long-term URL strategy; full column names are used instead.

### Per-subcat histogram behavior (Phase 3)

Each sub-category `<li>` gets a collapsible histogram slider panel using the same `slider_controller.js` already in use for paperwork violations.

Expand/collapse rules:
- Subcat checkbox **checked** → histogram panel opens by default
- Histogram panel can be **independently collapsed** via arrow toggle — slider values and checkbox state are preserved while collapsed
- Subcat checkbox **unchecked** → slider resets to domain defaults, histogram panel collapses

`collectFilters` for `health_subcat` type: for each checked subcat, always send both `_min` and `_max` from the slider's hidden inputs. No "is this the default range?" check needed — the slider always has values.

### Histogram data source

The legacy app computed histograms client-side from Mapbox vector tile features. The Rails app uses vector tiles — feature data is not available as JS objects. Use a **server-side histogram endpoint**:

```
GET /public_water_systems/histogram?field=paperwork_violations_5yr
→ { bins: [{ min: 0, max: 2, count: 412 }, ...], domain_min: 0, domain_max: 1070 }
```

Single SQL query against `violations_summaries` using PostgreSQL `width_bucket`. Response is cacheable (changes only on ETL import).

### Histogram render — `slider_controller.js`

This is the **T5-A** controller from the FE Architecture Plan. Stimulus controller (no chart library needed based on mock — the bars can be pure CSS/SVG). The mock shows a simple bar chart with no library-specific features.

**Do not add Highcharts or Chart.js.** The mock's design is achievable with inline SVG `<rect>` elements drawn by the controller. This avoids a CDN dependency and stays consistent with the no-build-step constraint.

**Controller spec:**
- **Values:** `fieldValue` (DB column name), `urlValue` (histogram endpoint)
- **Targets:** `chart` (svg element), `minHandle`, `maxHandle`, `minLabel`, `maxLabel`, `minInput` (hidden), `maxInput` (hidden)
- **On `connect()`:** fetch bins, render SVG bars at full range, position handles at extremes
- **On pointer drag:** update handle position and floating value label only — no server calls
- **On `pointerup` (commit):** write min/max to hidden inputs
- **Pattern:** commit-on-mouseup — `filter_controller.js` reads the hidden inputs on Apply; slider never calls Apply itself

---

## Implementation Plan

### Phase 1 — Sub-filter panels for Health violations
*No backend work. No design mock questions remaining. Ready to implement.*

#### Files to change

**1. `app/views/home/_filter_menus.html.erb`**

For `viols-health-5yrs` list item:
- Add `data-action="change->filter#toggleSubcat"` to the checkbox input
- After the `</li>`, add a hidden `<div id="subcat-health-5yr" class="hidden pl-4">` containing the 10 sub-category list items. Each checkbox gets:
  - `checked` attribute (starts checked)
  - `class="toggle default-checked viols-health-5yr-subcat"`
  - An `ⓘ` info icon (SVG or Unicode) after the label (per mock)

Repeat for `viols-health` (10yr) with panel ID `subcat-health-10yr` and class `viols-health-10yr-subcat`.

**2. `app/javascript/controllers/filter_controller.js`**

- Add `toggleSubcat(event)` method
- Add `health_subcat` type to `FILTERS` (replaces the two health `bool` entries):
  ```js
  { type: "health_subcat", group: 4, parentId: "viols-health-5yrs",
    panelId: "subcat-health-5yr", aggregateParam: "health_violations_5yr",
    subcats: [
      { id: "viols-groundwater-5yr",           param: "groundwater_rule_5yr" },
      { id: "viols-surface-water-5yr",         param: "surface_water_treatment_5yr" },
      { id: "viols-lead-copper-5yr",           param: "lead_and_copper_5yr" },
      { id: "viols-radionuclides-5yr",         param: "radionuclides_5yr" },
      { id: "viols-inorganic-5yr",             param: "inorganic_chemicals_5yr" },
      { id: "viols-synthetic-5yr",             param: "synthetic_organic_chemicals_5yr" },
      { id: "viols-vocs-5yr",                  param: "volatile_organic_chemicals_5yr" },
      { id: "viols-coliform-5yr",              param: "total_coliform_5yr" },
      { id: "viols-stage-1-disinfectants-5yr", param: "stage_1_disinfectants_5yr" },
      { id: "viols-stage-2-disinfectants-5yr", param: "stage_2_disinfectants_5yr" },
    ]
  },
  // (identical entry for 10yr, aggregateParam: "health_violations_10yr")
  ```
- Add `health_subcat` case to `#collectFilters()`, `#restoreDomState()`, `#resetMenu()`

**No new CSS.** Use `pl-4` Tailwind on the sub-filter wrapper div for indentation.

#### Test checklist
- [x] Checking parent reveals panel with all 10 checkboxes checked
  Fix: added `checked` HTML attribute to all 20 subcat inputs — `default-checked` class alone only drives `#resetMenu`, not initial browser rendering.
- [x] Unchecking parent hides panel, resets all sub-cat checkboxes to checked
- [x] Apply (all sub-cats checked) → `health_violations_5yr_min=1` in URL, no per-cat params
- [x] Apply (some sub-cats unchecked) → only checked sub-cats appear as `_min=1` params in URL
  Note: `_min=1` means "≥1 violation in this category." `filterable.rb` already handles `{column}_min` params as `WHERE column >= value` — no backend changes needed. A list param would have required new backend parsing.
- [x] Apply (parent unchecked) → no health violation params in URL
- [x] Reset restores parent to unchecked, panel hidden, sub-cats all checked
- [x] URL restore works for all-checked state
  Tests: with `?health_violations_5yr_min=1` in the URL (bookmarked/refreshed), parent should be checked, panel visible, all 10 subcats checked.
- [x] URL restore works for mixed-checked state
  Tests: with `?groundwater_rule_5yr_min=1&lead_and_copper_5yr_min=1` in the URL, parent should be checked, panel visible, only those 2 subcats checked.
- [x] Badge count: parent checked counts as 1 regardless of sub-cat state
  Future: could count active sub-cats instead of parent; deferred.

---

### Phase 2 — Histogram range sliders for Non-health violations (Tier 5)

This aligns with the **T5** milestone from `docs/frontend_refactor/FE_Architecture_Plan.md`. Design mocks are available — no longer blocked.

#### T5-B — Chart library decision

**Decision: no chart library.** The mock shows a minimal bar chart achievable with inline SVG `<rect>` elements. This keeps the no-build-step constraint and avoids a CDN dependency. Bars are drawn by `slider_controller.js` directly.

#### T5-A — `slider_controller.js`

**New file:** `app/javascript/controllers/slider_controller.js`

Visual spec from mocks:
- SVG `<rect>` bars, full-width within the menu panel, ~80px tall
- Brand blue `#1054A8` for bars inside the selected range; gray `#bfbfbf` for bars outside
- Two small filled black circle handles, sitting on the SVG baseline
- Floating value label above the active handle during drag (hide on release)
- Gray "Category description" / "Number of violations" label above the SVG
- Min value label bottom-left, max value label bottom-right
- When `domain_max === 1`: render as flat line (single segment), handles at both ends
- No y-axis, no gridlines

**Histogram API call spec:**
```
GET /public_water_systems/histogram?field=paperwork_violations_5yr
→ JSON: { bins: [{ min: 0, max: 2, count: 412 }, ...], domain_min: 0, domain_max: 1070 }
```
Fetch on `connect()`. Cache response in a module-level `Map` keyed by field name so reopening the menu doesn't re-fetch.

#### T5-A supporting backend files

1. **`config/routes.rb`** — add `resource :histogram, only: :show, module: :public_water_systems` inside the `collection` block (same pattern as `stats` and `export`)
2. **`app/controllers/public_water_systems/histograms_controller.rb`** — `PublicWaterSystems::HistogramsController#show`. Allowlist `field` against `ALLOWED_FIELDS`. Render JSON. (NOT in `public_water_systems_controller.rb`)
3. **`app/models/violations_summary.rb`** — add `self.histogram_bins(field, num_bins: 50)`. Use PostgreSQL `width_bucket`:
   ```sql
   SELECT width_bucket(field, min_val, max_val + 1, 50) AS bin,
          MIN(field) AS bin_min, MAX(field) AS bin_max, COUNT(*) AS count
   FROM violations_summaries
   GROUP BY bin ORDER BY bin
   ```
4. **`spec/requests/public_water_systems_spec.rb`** — histogram returns 200 + valid JSON; returns 400 for unknown field.
5. **`spec/models/violations_summary_spec.rb`** — `histogram_bins` returns correct bin structure.

#### T5-C — FILTERS config entries

Add to `FILTERS` array in `filter_controller.js` (replace the current `bool` entries for paperwork):
```js
{ type: "range", group: 4,
  param_min: "paperwork_violations_5yr_min", param_max: "paperwork_violations_5yr_max",
  parentId: "viols-paperwork-5yrs", panelId: "subcat-paperwork-5yr",
  minInputId: "min-paperwork-5yr", maxInputId: "max-paperwork-5yr" },
{ type: "range", group: 4,
  param_min: "paperwork_violations_10yr_min", param_max: "paperwork_violations_10yr_max",
  parentId: "viols-paperwork", panelId: "subcat-paperwork-10yr",
  minInputId: "min-paperwork", maxInputId: "max-paperwork" },
```

Add `range` case to `#collectFilters()`: only send params if parent is checked and value differs from the full-domain default. Add `range` case to `#restoreDomState()`.

#### T5-D — `_filter_menus.html.erb` slider markup

After the `viols-paperwork-5yrs` `<li>`, insert (hidden by default, revealed via `toggleSubcat`):

```html
<div id="subcat-paperwork-5yr" class="hidden px-4 py-2"
     data-controller="slider"
     data-slider-field-value="paperwork_violations_5yr"
     data-slider-url-value="/public_water_systems/histogram">
  <p class="text-xs text-neutral-400 mb-1">Number of violations</p>
  <svg data-slider-target="chart" class="w-full" height="80"></svg>
  <div class="flex justify-between text-xs mt-1">
    <span data-slider-target="minLabel"></span>
    <span data-slider-target="maxLabel"></span>
  </div>
  <input type="hidden" data-slider-target="minInput" id="min-paperwork-5yr">
  <input type="hidden" data-slider-target="maxInput" id="max-paperwork-5yr">
</div>
```

Repeat for `viols-paperwork` (10yr). The `toggleSubcat` action on the parent checkbox also controls the histogram panel (same mechanism as Phase 1 sub-cat panels).

#### T5 test checklist
- [ ] Checking parent reveals histogram panel; histogram loads and renders
- [ ] Dragging min handle grays bars to the left; value tooltip shows current value
- [ ] Dragging max handle grays bars to the right
- [ ] Releasing handle commits values to hidden inputs
- [ ] Apply sends `paperwork_violations_5yr_min=N&paperwork_violations_5yr_max=M` in URL
- [ ] Unchecking parent hides histogram, clears min/max params on Apply
- [ ] Reset restores parent to unchecked, histogram hidden, params cleared
- [ ] URL restore sets slider positions correctly
- [ ] Edge case: `domain_max === 1` renders flat line
- [ ] Histogram data is cached — reopening menu does not re-fetch
- [ ] Histogram endpoint returns 400 for unknown field names (security)

---

## Status

| Item | Status |
|---|---|
| Research & plan document | Done (this doc) |
| Design mocks reviewed | Done — see `docs/mocks/subfilters_and_histograms/` |
| Phase 1: Sub-filter panels — 5yr health violations | Done |
| Phase 1: Sub-filter panels — 10yr health violations | Done |
| Phase 2 (T5-A): `slider_controller.js` | Done |
| Phase 2 (T5-A): Histogram API endpoint + model method | Done |
| Phase 2 (T5-C): FILTERS config — `range` type | Done |
| Phase 2 (T5-D): Slider markup in `_filter_menus.html.erb` | Done |
| Phase 2 (T5): Manual UI testing — T5 checklist | Pending |
| Phase 2: Visual styling polish | Pending — needs design input |
| Phase 3: Per-sub-category histograms under health violations | Done |

---

## Known Limitations / Follow-up Items

- **Slider fetch on page load**: `slider_controller.js` fires its histogram fetch on `connect()`, which runs on page load even when the panel is hidden. With 20 health subcat sliders + 2 paperwork sliders, 22 JSON requests fire on every page load regardless of whether the user opens the Compliance menu. However, the module-level `CACHE` map (keyed by field name) means each unique field only fetches once per browser session — subsequent panel opens re-use cached data. Acceptable for now; could be deferred to first-reveal with an IntersectionObserver if needed.

- **Slider reset visual**: Clicking Reset clears hidden inputs and calls `resetToFullRange()` on the slider controller, but only if the histogram is rendered by that point. If Reset is clicked before the async fetch completes, handles stay at the last committed position until the user re-opens the panel. Edge case; not worth addressing now.

- **`toggleSubcat` closes then re-opens**: If a user unchecks the parent and re-checks it quickly, subcat checkboxes are reset to all-checked but the slider (if already rendered) stays at domain extremes. Correct behavior.

---

## Session Log

| Date | Agent | Notes |
|---|---|---|
| 2026-05-05 | Research session | Analyzed legacy `deprecated/inc-map.php`, `filter_controller.js`, `filterable.rb`, and all 3 design mocks. Wrote this plan. Backend already supports all needed params — no backend work for Phase 1. Phase 2 no longer blocked by design. Start with Phase 1. |
| 2026-05-05 | Implementation session | Implemented all Phase 1 and Phase 2 items. All 487 specs pass, rubocop clean. See below for detail. |
| 2026-05-05 | Refactor session | Moved histogram action out of `public_water_systems_controller.rb` into `app/controllers/public_water_systems/histograms_controller.rb` (matching `stats`/`exports` pattern). Changed route from `get :histogram` to `resource :histogram, only: :show, module: :public_water_systems`. Fixed invalid HTML: all four subcat/histogram `<div>` panels were siblings of `<li>` inside `<ul>` (invalid); moved inside their parent `<li>`. 487 specs still pass. |
| 2026-05-05 | Cleanup + logic session | (1) Created `app/assets/images/icons/arrow-down.svg`; replaced all 4 inline SVG chevrons in `_filter_menus.html.erb` with `icon()` helper. (2) Fixed subcat filter logic from AND to OR: multiple checked subcats in the same time window now match any (not all) — via a new OR `WHERE` clause in `filterable.rb`. (3) Renamed all health violation params to boolean style: individual subcats `groundwater_rule_5yr_min=1` → `groundwater_rule_5yr=true`; aggregate `health_violations_5yr_min=1` → `health_violations_5yr=true`. Added `HEALTH_SUBCAT_5YR`, `HEALTH_SUBCAT_10YR`, `HEALTH_SUBCATS_ALL` constants. Specs updated and expanded (OR logic, cross-window AND, aggregate cases). 491 specs pass. **Next: manual UI testing per test checklists above.** |
| 2026-05-05 | Verification + docs session | Confirmed histograms render with real production data: `paperwork_violations_5yr` range is 1–1,070 (24,235 systems with ≥1 violation). `histogram_bins` uses `MAX(field)` as `domain_max` — 1,070 is the actual outlier, not a synthetic cap. Added 6 missing `filterable_spec.rb` specs covering `paperwork_violations_5yr/10yr` min/max and range — 497 specs pass. T5 manual UI testing still pending. Phase 3 (per-sub-category histograms) blocked on design input and param strategy — see Phase 3 section above. |
| 2026-05-05 | Phase 3 implementation session | Implemented Phase 3 in full. Health subcat params switched from boolean (`groundwater_rule_5yr=true`) to range (`groundwater_rule_5yr_min=N&max=M`). `filterable.rb` Arel OR-range logic added for health subcats; `PAPERWORK_VIOLATIONS_COLS` constant extracted. Short-alias approach (`soc_5yr` etc.) was explored and reverted — full DB column names used throughout. `HistogramsController::ALLOWED_FIELDS` expanded to 22 (all subcat columns + paperwork). All 20 subcat `<li>` items in `_filter_menus.html.erb` now render `_slider_panel.html.erb` partial. 473 specs pass. |
| 2026-05-05 | Simplify + cleanup session | `slider_controller.js`: fixed mid-drag `pointermove` listener leak in `disconnect()`; cached `getBoundingClientRect()` in `#onDown` (eliminates forced layout reflow on every mousemove). `filter_controller.js`: removed dead `field:` key from all 20 subcat FILTERS entries; extracted `#hideAndResetSlider(panel)` private method (was copy-pasted across 3–4 locations). `_slider_panel.html.erb` partial extracted from 20 identical inline blocks in `_filter_menus.html.erb`. `filterable.rb`: extracted `min_val`/`max_val` locals inside Arel block (was 2–3 hash lookups per iteration). 473 specs pass. |

### Implementation detail (2026-05-05)

**`filter_controller.js`**
- Added `health_subcat` type replacing the two `bool` health violation entries. Includes `toggleSubcat(event)` action (uses `data-panel-id` attribute on parent checkbox to locate panel by ID).
- Added `range` type replacing the two `bool` paperwork entries.
- `GROUP_KEYS` excludes `health_subcat` and `range` types; badge counting handled separately via `HEALTH_SUBCAT_FILTERS` and `RANGE_FILTERS` module-level arrays.
- `#resetMenu` hides `[data-subcat-panel]` divs and calls `slider.resetToFullRange()` via `this.application.getControllerForElementAndIdentifier`.

**`_filter_menus.html.erb`** (compliance section)
- Each parent `<li>` now contains its subcat panel `<div>` as a child (valid HTML, `<div>` not a sibling of `<li>` in `<ul>`).
- 10 subcat checkboxes per health panel, all `default-checked`, with ⓘ tooltips sourced from `deprecated/assets/js/tooltips.js`.
- Histogram panels carry `data-controller="slider"` with `field` and `url` values.

**Backend**
- `ViolationsSummary.histogram_bins(field, num_bins: 50)` — PostgreSQL `width_bucket`, excludes null/zero, returns `{bins, domain_min, domain_max}`.
- `PublicWaterSystems::HistogramsController#show` — allowlists field param against `ALLOWED_FIELDS`, returns JSON.
- Route: `resource :histogram, only: :show, module: :public_water_systems`.
- Model spec + request spec added; all green.

---

## Phase 3 — Per-sub-category histograms

Approach and param strategy are now decided (see Architecture section above). Ready to implement.

### What changes from current state

| | Current (boolean) | Phase 3 (range) |
|---|---|---|
| Subcat param style | `groundwater_rule_5yr=true` | `groundwater_rule_5yr_min=1&groundwater_rule_5yr_max=45` |
| Aggregate param | `health_violations_5yr=true` → backend filter | UI-only toggle, no backend handling, removed from `filterable.rb` |
| Backend OR logic | `WHERE (col_a >= 1 OR col_b >= 1)` | `WHERE (col_a >= min AND col_a <= max) OR (col_b >= min AND col_b <= max)` |
| Each subcat has slider | No | Yes — same `slider_controller.js` as paperwork violations |

### URL examples

**Two subcats active, at domain defaults (min=1, max=domain_max):**
```
?groundwater_rule_5yr_min=1&groundwater_rule_5yr_max=45&synthetic_organic_chemicals_5yr_min=1&synthetic_organic_chemicals_5yr_max=8
```

**Two subcats with custom ranges (user has moved sliders):**
```
?groundwater_rule_5yr_min=5&groundwater_rule_5yr_max=20&synthetic_organic_chemicals_5yr_min=3&synthetic_organic_chemicals_5yr_max=8
```

**Mixing 5yr and 10yr (AND across windows):**
```
?groundwater_rule_5yr_min=1&groundwater_rule_5yr_max=45&groundwater_rule_10yr_min=3&groundwater_rule_10yr_max=30
```

**Mixed: health subcats + paperwork range + other filters:**
```
?groundwater_rule_5yr_min=1&groundwater_rule_5yr_max=45&synthetic_organic_chemicals_5yr_min=1&synthetic_organic_chemicals_5yr_max=8&paperwork_violations_5yr_min=1&paperwork_violations_5yr_max=100&system_type[]=CWS
```

Note: all active subcats always send both `_min` and `_max` — the slider always has values from the domain fetch.

### Files to change

**1. `app/models/concerns/filterable.rb`** (done)
- Added `PAPERWORK_VIOLATIONS_COLS = %i[paperwork_violations_5yr paperwork_violations_10yr].freeze` constant (referenced by `HistogramsController::ALLOWED_FIELDS`)
- Removed `health_violations_5yr` and `health_violations_10yr` aggregate boolean code paths
- Changed health subcat filtering from OR-boolean to OR-range: `WHERE (col_a >= min AND col_a <= max) OR (col_b >= min AND col_b <= max)` within each time window, using Arel
- URL params use full DB column names (`groundwater_rule_5yr_min`, not aliases). A short-alias approach was explored and reverted — aliases added complexity without a clear long-term URL strategy.
- `HEALTH_SUBCAT_5YR`, `HEALTH_SUBCAT_10YR`, `HEALTH_SUBCATS_ALL` constants define the 10 columns per window

**2. `app/javascript/controllers/filter_controller.js`** (done)
- `health_subcat` filter entries: each subcat has `param_min`/`param_max` using full DB column names (e.g. `groundwater_rule_5yr_min`)
- `#collectFilters()` health_subcat case: for each checked subcat, always sends both `_min` and `_max` from the slider's hidden inputs
- `#restoreDomState()` health_subcat case: restores hidden inputs from URL params; slider reads them on connect to restore handle positions
- `#hideAndResetSlider(panel)` private method extracted — resets hidden inputs and calls `resetToFullRange()` on the slider; called from `toggleSubcat`, `syncParentFromSubcat`, and `#resetMenu`
- Removed aggregate param logic (`allChecked` → `aggregateParam` path)

**3. `app/controllers/public_water_systems/histograms_controller.rb`** (done)
- `ALLOWED_FIELDS` expanded to 22 fields: `Filterable::PAPERWORK_VIOLATIONS_COLS + Filterable::HEALTH_SUBCATS_ALL` (all 10 subcat columns × 2 time windows, DB column names)

**4. `app/views/home/_filter_menus.html.erb`** (done)
- Each of the 20 health subcat `<li>` items now renders `<%= render "slider_panel", ... %>` with the DB column name as `field`. Slider panels extracted to `app/views/home/_slider_panel.html.erb` partial.

**5. `spec/models/concerns/filterable_spec.rb`** (done)
- Range specs added for health subcat columns, following the paperwork range specs pattern
- OR-within-window spec: two subcats active → returns systems matching either
- AND-between-windows spec: 5yr and 10yr both active → must satisfy both

### Test checklist (manual UI)
- [ ] Checking a health subcat checkbox reveals histogram panel, histogram loads and renders
- [ ] Histogram panel can be collapsed via arrow while checkbox stays checked and slider values persist
- [ ] Unchecking a subcat resets slider to domain defaults and collapses the histogram panel
- [ ] Dragging subcat slider grays bars outside range and shows value tooltip
- [ ] Apply sends `{column}_min=N&{column}_max=M` (full DB column name) for each checked subcat
- [ ] Apply sends nothing for unchecked subcats
- [ ] URL restore: bookmarked URL with `?groundwater_rule_5yr_min=5&groundwater_rule_5yr_max=20` restores checkbox checked, panel open, slider at correct position
- [ ] OR logic: two subcats active at default range returns systems with violations in either category
- [ ] AND logic: 5yr and 10yr subcats both active returns only systems satisfying both windows
- [ ] Reset clears all subcat sliders and collapses all histogram panels
- [ ] Histogram endpoint returns 400 for a health subcat field not in `ALLOWED_FIELDS`

### Spec test cases (code)

Follow the pattern in `spec/models/concerns/filterable_spec.rb` under `"paperwork violations range filters"`. Key cases to cover:

```
"health subcat range filters" do
  # Basic range per column (full DB column name)
  filters by groundwater_rule_5yr_min
  filters by groundwater_rule_5yr_max
  filters by groundwater_rule_5yr range (min AND max)

  # OR within time window
  two subcats active → returns systems matching either (not requiring both)

  # AND between time windows
  5yr and 10yr subcats both active → returns only systems satisfying both

  # Aggregate param removed
  health_violations_5yr=true → ignored, returns all systems (no filter applied)
end
```

---

## Out of Scope (for now)

- Boil water notices histogram (parent checkbox is disabled)
- EJScreen drinking water non-compliance indicator (commented out in legacy)
