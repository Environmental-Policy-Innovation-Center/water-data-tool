# Data Table — Decisions, Implementation Plan, and Testing Plan

The data table is a core feature of the app. This document captures all design decisions, differences from the legacy app, and the full implementation + test plan. It is written to be picked up by a new agent with no prior context.

---

## Design Mock

Data table mock

Key things visible in the mock (implement all of these):

- Filter pill bar at top (already implemented)
- "Public Water Utilities in [Area Name]" title at left; Export button + .csv / .geojson radio at right
- **Checkbox column** as the leftmost column (header checkbox = select all; row checkboxes = individual selection for subset export)
- Column headers with a **bi-directional sort icon** (↕ when unsorted, ↑ or ↓ when active)
- **Alternating row striping** (white / light gray)
- **Checked rows** appear with a distinct background (selected state)
- **Prominent scrollbars** — both vertical and horizontal, visible and styled
- Horizontal scrollbar pinned to the bottom of the viewport (not just the end of the table)
- Map / Table toggle buttons at bottom right

---

## Decisions

### 1. Sort states

**Decision:** 3-state sort — unsorted (↕) → ascending (↑) → descending (↓) → unsorted (↕).

**Why:** The legacy DataTables app used 3-state by default. The mock shows a ↕ icon on all columns (unsorted state), consistent with this behavior. The "reset to unsorted" state is useful for returning to the default `pws_name ASC` order without reloading.

**Implemented:** `table_sort_link` in `app/helpers/home_helper.rb` cycles unsorted → asc → desc → unsorted. Third click drops `sort`/`direction` params entirely, returning to default `pws_name ASC` order. Icon is stacked ▲▼ triangles — active direction renders `text-gray-600`, inactive renders `text-gray-300`. Only the label underlines on hover (not the icon) via Tailwind `group`/`group-hover:underline`.

### 2. NULL ordering

**Decision:** `NULLS LAST` always — both `ASC` and `DESC`.

**Why:** PostgreSQL defaults to `NULLS LAST` for `ASC` but `NULLS FIRST` for `DESC`, which means descending sorts put null rows at the top. Users expect missing data to be out of the way regardless of direction. `NULLS LAST` on both directions is the conventional fix.

**Legacy behavior:** The PHP app coerced nulls to `0` (numerics) or `""` (strings) before client-side DataTables sorted them. That approach is not appropriate for server-side SQL — sort against the DB value instead.

**Implemented:** `HomeController#order_clause` uses `Arel.sql("public_water_systems.#{col} #{dir} NULLS LAST#{tiebreaker}")` where `tiebreaker` appends `, public_water_systems.pws_name ASC` for all non-name sorts.

### 3. NULL display

**Decision:** Render `nil` DB values as `"—"` (em dash) in all cells. Do not show `"NA"`, `"N/A"`, `0`, or empty string.

**Why:** `"—"` is the conventional typographic placeholder for missing data in data tables. `0` and `""` are misleading — they imply a real value of zero or an empty string, not absence of data.

**Implemented:** All cells use a nil-safe helper:

- Numeric columns: `fmt_num`, `fmt_dec`, `fmt_pct`, `fmt_cur` (all return `"—"` for nil)
- Boolean columns: `fmt_bool(val)` — `"Yes"` / `"No"` / `"—"` for nil
- String columns: `fmt_str(val)` — returns `val.presence || "—"`

### 4. Sort tiebreaker

**Decision:** Always append `pws_name ASC` as a secondary tiebreaker on every `ORDER BY`.

**Why:** Deterministic ordering — ties on the primary sort column resolve alphabetically by utility name. This matches the legacy app's behavior (the JS array was pre-sorted by `pws_name ASC` before DataTables received it, making name the implicit tiebreaker).

**Implemented:** `order_clause` skips the tiebreaker when `pws_name` is the primary sort column (no duplicate `pws_name ASC, pws_name ASC`). For all other columns, `, public_water_systems.pws_name ASC` is appended.

### 5. Sortable columns

**Decision:** All data columns are sortable. The EPA Facility Report column is not sortable (it contains a link, not a sortable value).

**Currently sortable** (in `SORTABLE_COLUMNS` in `HomeController`):
`pws_name`, `pwsid`, `stusps`, `counties`, `gw_sw_code`, `source_water_protection_code`, `owner_type`, `primacy_type`, `is_wholesaler`, `is_school_or_daycare`, `symbology_field`, `area_sq_miles`, `open_health_viol`

**Not yet sortable** (violation counts, demographics, EJ, funding, watershed — these require joining associated tables in the sort; to be added in a follow-up).

**Not sortable by design:** EPA Facility Report (link column).

### 6. Row checkboxes

**Decision:** Add a checkbox column as the leftmost column. Header checkbox = select all visible rows. Row checkboxes = individual row selection. Selected rows export when the Export button is clicked (if rows are selected, export only selected; if none selected, export all).

**Why:** Visible in the design mock. Allows users to build a custom subset for export.

**Status: Deferred — see P3.** Do not implement until explicitly requested. When picked up, this is client-side state only — no server roundtrip needed. A `table_select_controller` Stimulus controller (or inline `data-action` on the export controller) can collect checked `pwsid` values and pass them as a hidden field or query param on export.

---

## Notable Differences from Legacy


| Topic           | Legacy (PHP + DataTables)                                | Current Rails Implementation                                          |
| --------------- | -------------------------------------------------------- | --------------------------------------------------------------------- |
| Sort engine     | Client-side DataTables (all data in memory)              | Server-side SQL (`ORDER BY` in `HomeController#table`)                |
| NULL handling   | Coerced to `0` (numeric) or `""` (string) before sorting | Sort against DB `NULL` with `NULLS LAST`                              |
| NULL display    | `0` or empty string                                      | `"—"` (em dash) via `fmt_`* helpers                                   |
| Boolean display | `true` / `false`                                         | `"Yes"` / `"No"` (or `"—"` for nil)                                   |
| Sort states     | 3-state (DataTables default)                             | 3-state — unsorted → asc → desc → unsorted; third click clears params |
| Tiebreaker      | Implicit (array pre-sorted by `pws_name ASC`)            | Explicit `pws_name ASC` appended to every `ORDER BY`                  |
| Pagination      | Client-side (all rows loaded)                            | Server-side via Pagy                                                  |


---

## Full Implementation Plan

Work items in suggested implementation order. All changes are self-contained in the files listed under Key Files.

### P1 — Correctness ✅ Done


| Item                                | File(s)              | Status                                                                                                                                                         |
| ----------------------------------- | -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **NULLS LAST** on all sorts         | `home_controller.rb` | ✅ `order_clause` uses `#{dir} NULLS LAST` + `pws_name ASC` tiebreaker                                                                                          |
| **Nil display audit** — raw columns | `_table.html.erb`    | ✅ String columns use `fmt_str(val)`, numeric/decimal/pct/currency columns use `fmt_num`/`fmt_dec`/`fmt_pct`/`fmt_cur`, boolean nil uses `fmt_bool`             |
| **3-state sort** in helper          | `home_helper.rb`     | ✅ Cycles unsorted (↕) → asc (↑) → desc (↓) → unsorted; third click drops `sort`/`direction` params; `aria_sort` returns `"none"` for unsorted sortable columns |


### P2 — Layout and UX ✅ Done


| Item                                    | File(s)                             | Status                                                                                                                                                                                                                                           |
| --------------------------------------- | ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Sticky column headers**               | `_table.html.erb`                   | ✅ `sticky top-0 z-20` on `th`/`th_sm`; corner cell (`th_sticky`) gets `left-0 top-0 z-30`. Single `overflow-auto` scroll container (`.table-scroll`) required — dual-axis scroll broke stickiness.                                               |
| **Sticky first column**                 | `_table.html.erb`                   | ✅ "Utility Name" `th`/`td` use `sticky left-0`; corner cell is `z-30` to stay above both axes simultaneously                                                                                                                                     |
| **Column min-width**                    | `_table.html.erb`                   | ✅ `whitespace-nowrap` on all `th` + `min-w-[8/10/12rem]`; `max-w-48` on `td` caps cell-driven growth                                                                                                                                             |
| **Column highlight when sorted**        | `_table.html.erb`, `home_helper.rb` | ✅ `col_highlight(column)` returns `" bg-blue-100/30"` (semi-transparent so row stripe shows through); applied to all 13 sortable `td` cells; sticky name column uses solid `bg-blue-50` to mask scrolled content                                 |
| **Scrollbars always visible**           | `water_tool.css`                    | ✅ Single `.table-scroll { overflow: auto }` container; `::-webkit-scrollbar` + `scrollbar-width: thin` styled; horizontal bar pinned at bottom of viewport (not end of table)                                                                    |
| **Row striping**                        | `_table.html.erb`                   | ✅ `row_stripe` computed from `idx.even?` (white / `bg-gray-50`) applied to both `<tr>` and the sticky name cell — single source of truth for row color                                                                                           |
| **Row hover**                           | `_table.html.erb`                   | ✅ `hover:bg-blue-50 transition-colors` on every `<tr>`                                                                                                                                                                                           |
| **Sort arrows — no underline on hover** | `home_helper.rb`                    | ✅ Tailwind `group`/`group-hover:underline` on label span only; sort icon span excluded                                                                                                                                                           |
| **Export button size**                  | `water_tool.css`                    | ✅ Padding `7px 13px 7px 38px`; font-size `0.875em`; icon 16px                                                                                                                                                                                    |
| **Table header padding**                | `app/views/home/index.html.erb`     | ✅ `py-5` on `.table-header`; radio inputs spaced with `ml-4`/`ml-3`                                                                                                                                                                              |
| **Pagination footer**                   | `_table.html.erb`                   | ✅ 3-column pinned `<nav>`: col-1 left "Showing X to Y of Z entries", col-2 center «/‹/[page input]/›/» with jump-to-page form, col-3 right Map/Table toggle. Footer is `flex-shrink-0` and sits below the scroll region — does not overlap rows. |
| **Horizontal scroll preservation**      | `table_frame_controller.js`         | ✅ Stimulus controller on `<turbo-frame id="data-table">` intercepts `turbo:before-frame-render`, wraps `event.detail.render` to restore `scrollLeft` in the same microtask as the DOM swap — no visible flash                                    |


### P3 — Row selection and export ⏸ On Hold

Row checkboxes and subset export are deferred. Do not implement until explicitly requested. The design mock shows checkboxes, but the feature requires decisions about export scope (current page vs. all pages) and is non-trivial to wire correctly across Turbo Frame reloads.

When this is picked up:


| Item                       | File(s)                             | Detail                                                                                                                                                     |
| -------------------------- | ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Checkbox column**        | `_table.html.erb`                   | Add `<th>` with header checkbox (select all) and `<td>` with row checkbox in each row. Use `data-pwsid` on each row checkbox                               |
| **Select-all behavior**    | New or existing Stimulus controller | Header checkbox checks/unchecks all visible row checkboxes                                                                                                 |
| **Subset export**          | `export_controller.js`              | If any checkboxes are checked, collect their `pwsid` values and pass as `pwsids[]` param on export request. If none checked, export all (current behavior) |
| **Selected row highlight** | `_table.html.erb` / CSS             | Checked rows show a distinct background (visible in mock as slightly darker gray)                                                                          |


### P4 — Spec coverage


| Item                                  | File(s)                      | Status                                                                                                                                                                                  |
| ------------------------------------- | ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Assert NULLS LAST**                 | `spec/requests/home_spec.rb` | ✅ Done — `sorts null values last when sorting ascending` and `…descending` both pass                                                                                                    |
| **Assert 3-state sort reset**         | `spec/requests/home_spec.rb` | ✅ Done — `sorts ascending by pws_name by default` covers the no-`sort`-param case                                                                                                       |
| **Assert nil renders as "—"**         | `spec/requests/home_spec.rb` | ⚠️ Partial — `renders — for nil boolean columns, not No` covers booleans; nil numeric/string associations (violations_summary, demographic, etc.) have no dedicated nil-render spec yet |
| **Assert all column headers present** | `spec/requests/home_spec.rb` | ⏳ Not done — `renders column headers` only checks "Utility Name", "State", "County"; a full column-header sweep spec is not yet written                                                 |


---

## Key Files and Patterns

```
app/views/home/_table.html.erb      ← table partial (Turbo Frame wrapper + all HTML)
app/helpers/home_helper.rb          ← table_sort_link, col_highlight, aria_sort, fmt_str, fmt_bool, fmt_num, fmt_dec, fmt_pct, fmt_cur
app/controllers/home_controller.rb  ← HomeController#table action, SORTABLE_COLUMNS allowlist, ORDER BY logic
app/javascript/controllers/
  table_frame_controller.js         ← preserves horizontal scroll position across Turbo Frame reloads
  filter_controller.js              ← reloads data-table Turbo Frame on filter change
  export_controller.js              ← handles Export button click and file type selection
app/assets/stylesheets/water_tool.css  ← legacy CSS; table flex layout, scrollbar styling, export button
spec/requests/home_spec.rb          ← all request specs for the table action
docs/mocks/data_table_mock.png      ← Figma design mock (reference for visual implementation)
```

### Sort link pattern (current — `home_helper.rb`)

```ruby
def table_sort_link(column, label)
  is_sorted = params[:sort] == column
  current_dir = params[:direction] == "desc" ? "desc" : "asc"

  next_url = if is_sorted && current_dir == "desc"
    url_for(request.query_parameters.except("sort", "direction").merge("page" => 1))
  elsif is_sorted
    url_for(request.query_parameters.merge("sort" => column, "direction" => "desc", "page" => 1))
  else
    url_for(request.query_parameters.merge("sort" => column, "direction" => "asc", "page" => 1))
  end

  up_class   = (is_sorted && current_dir == "desc") ? "text-gray-600" : "text-gray-300"
  down_class = (is_sorted && current_dir == "asc")  ? "text-gray-600" : "text-gray-300"
  sort_icon = content_tag(:span, class: "inline-flex flex-col leading-none flex-shrink-0") do
    safe_join([
      content_tag(:span, "▲", class: "block text-[8px] leading-none #{up_class}"),
      content_tag(:span, "▼", class: "block text-[8px] leading-none #{down_class}")
    ])
  end

  link_to next_url, class: "flex items-center justify-between gap-2 w-full group focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-400 focus-visible:ring-offset-1 rounded-sm" do
    safe_join([content_tag(:span, label, class: "group-hover:underline"), sort_icon])
  end
end
```

### SORTABLE_COLUMNS allowlist (current — `home_controller.rb`)

```ruby
SORTABLE_COLUMNS = %w[
  pws_name pwsid stusps counties gw_sw_code source_water_protection_code
  owner_type primacy_type is_wholesaler is_school_or_daycare symbology_field
  area_sq_miles open_health_viol
].freeze
```

This is an SQL injection allowlist — only column names in this list are allowed in `ORDER BY`. It does not control column display order in the table.

### Turbo Frame loading

The table renders inside `<turbo-frame id="data-table">` in `app/views/home/index.html.erb`. `filter_controller.js` calls `Turbo.visit("/table?#{FilterState.toUrlParams()}", { frame: "data-table" })` when filters change or when the user switches to Table view. The `/table` route hits `HomeController#table` which renders `home/table` (the `_table.html.erb` partial).

### Format helpers (nil → "—")

All format helpers live in `home_helper.rb` and return `"—"` for nil:

- `fmt_str(val)` — string presence check, returns `"—"` for nil/blank
- `fmt_bool(val)` — `"Yes"` / `"No"` / `"—"` for nil
- `fmt_num(val)` — integer with thousands separator
- `fmt_dec(val, precision: 2)` — float with delimiter
- `fmt_pct(val, precision: 2)` — percentage
- `fmt_cur(val, precision: 0)` — currency

---

## Manual Test Plan

Run `bin/dev` and open the app. Click the **Table** toggle at bottom-right to switch to table view. Use a dataset with real data (production or seeded dev DB).

### P1 — Correctness

- **Default sort**: Table loads sorted A→Z by utility name. All other column headers show ↕ icon.
- **Sort ascending**: Click any sortable column header → ↑ icon appears; data re-sorts ascending.
- **Sort descending**: Click the same header again → ↓ icon appears; data re-sorts descending.
- **Sort reset (3-state)**: Click the same header a third time → ↕ icon returns; table reverts to `pws_name ASC` order.
- **NULLS LAST**: Sort any column descending → rows with "—" appear at the BOTTOM, not the top. *(Covered by spec; visually confirm with a page jump to the last page on a sparse column like area_sq_miles)*
- **Nil string display**: Find a system with no county or source-type data; confirm cell shows "—" not empty/NA/0.
- **Nil boolean**: Find a system with nil wholesaler status; confirm cell shows "—" not "No". 
- **False boolean**: A system with `is_wholesaler: false` shows "No".
- **True boolean**: A system with `is_wholesaler: true` shows "Yes".

### P2 — Layout and UX

- **Sticky headers**: Scroll down → column headers stay fixed at the top of the viewport.
- **Sticky first column**: Scroll right → "Utility Name" column stays fixed at the left edge.
- **Corner cell**: Scroll both right and down → the "Utility Name" header stays pinned at the top-left corner (both sticky axes active simultaneously).
- **No wrapping headers**: Every column header displays on a single line. In particular: "EPA Facility Report", "Facility type (School or daycare)", and all long violation headers (e.g., "Synthetic organic chemicals violations (5yr)") are one line.
- **Column highlight**: Click a sort column → that column's `td` cells show a subtle blue tint. Click to reset sort → tint disappears.
- **Scrollbars styled**: Horizontal and vertical scrollbars are visibly styled (not the browser-default near-invisible thin bars).
- **Row striping**: Even rows have a light gray background; odd rows are white.
- **Row hover**: Hovering over any row shows a blue-tinted row highlight.
- **Empty state**: Apply filters that return 0 results → shows "No results match the current filters." *(HTML is in place — verify visually with an impossible filter combo)*
- **Pagination**: 3-column pinned footer — "Showing X to Y of Z entries" left, «/‹/[page input]/›/» centered, Map/Table toggle right. Jump-to-page input navigates directly. All elements on the same horizontal level, does not overlap table rows.
- **Single page**: With ≤50 rows, shows "Showing N entries" with no nav buttons.

## *For color choices, reference the Legacy App in the /deprecated dir to see if that info is available - if so lets copy those color selections*

### Other Pieces of Work TODO

**Remaining table tasks:**

- **Empty state** — verify visually by applying an impossible filter combo (HTML markup is in place)
- **index.html.erb `table-header` div** — still uses legacy CSS class; migrate to Tailwind utilities (see "When `water_tool.css` Is Deprecated" below)
- **"Public Water Utilities in [Place]" dynamic title** — implement geo-filter title injection using Stimulus.
  - **What it should do:** When a place/state/boundary filter is active, the table title reads "Public Water Utilities in Colorado" (or whatever the active geo name is). When no geo filter is active, it reads "Public Water Utilities". Both the table header (`index.html.erb:149`) and the boil-water filter notice (`_filter_menus.html.erb:119`) contain `<span class="geo-filter"></span>` slots for this text.
  - **Legacy behavior:** The PHP app rendered this server-side. In the current app these spans are always empty — no JS writes to them yet.
  - **Where the data already lives:** `filter_controller.js` already holds `params.place_name` (set at line 321 during `#restoreFromUrl`). The active place name is available at apply time via the geocoder input or the `place_name` URL param.
  - **Stimulus approach (preferred):** Add a `place-name` Stimulus value to the `filter` controller (already on `#container-map`). When a place filter is applied or cleared, update `this.placeNameValue`. Add a value changed callback that queries `document.querySelectorAll(".geo-filter")` and sets their `textContent` to `"in #{placeName}"` or clears it. No new controller needed — this is a small addition to `filter_controller.js`.
  - **Note:** `<span class="geo-filter">` appears in two places; both update automatically via `querySelectorAll`. When the ViewComponent migration happens, this slot should become a Stimulus target instead of a bare CSS class selector.

**Filters:**

- Add remaining sortable columns (violation counts, demographics, EJ, funding, watershed) to `SORTABLE_COLUMNS` + add corresponding `home_spec.rb` tests
- Source: Place filter — add bottom padding inside the scroll modal so results aren't hidden behind the Reset/Apply buttons
- Source protection filter — investigate why some values are `'No information'` and others are `nil`; normalize during ETL or at display layer

**Data integrity:**

- Determine if/why a PWS can have multiple pwsids stored as a semicolon-delimited string (e.g., `"ND0501057; ND0501127; ND4001153; ND3501476"`)
- Decide on `nil` vs `'NA'` storage convention — may require a forced ETL re-run (confirm ETL creates new DB records vs. upserts)
- Investigate all data types for boolean and similar type data columns, determine how to handle `nil`, `NA`, and `No Information` type columns.

---

## When `water_tool.css` Is Deprecated

The following table-related rules currently live in `water_tool.css` with `/* TEMP */` comments or similar notes. When the CSS file is deprecated in favor of Tailwind utilities, these need specific attention:


| Rule                                                                                                                               | Current location | Migration path                                                                                                                                                                                                |
| ---------------------------------------------------------------------------------------------------------------------------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `#container-table .container-section-inner` — flex column layout (`flex: 1; min-height: 0; display: flex; flex-direction: column`) | `water_tool.css` | Move to Tailwind classes on the `.container-section-inner` div in `index.html.erb`: `class="flex flex-col flex-1 min-h-0 p-5 pb-0"`                                                                           |
| `turbo-frame#data-table` — flex column (`display: flex; flex-direction: column; flex: 1; min-height: 0`)                           | `water_tool.css` | Move to Tailwind on the `<turbo-frame>` element in `_table.html.erb`: `class="flex flex-col flex-1 min-h-0"`                                                                                                  |
| `#container-map.table-mode #container-table` — display toggle to `flex`                                                            | `water_tool.css` | This is toggled by JS adding `.table-mode` on `#container-map`. Options: (a) keep in CSS as a class-toggle rule, or (b) have the nav Stimulus controller add Tailwind classes directly instead of a CSS class |
| `.table-scroll` — `::-webkit-scrollbar` + `scrollbar-width: thin` scrollbar styling                                                | `water_tool.css` | `::-webkit-scrollbar` pseudo-elements are not supported by Tailwind without a custom plugin. Keep in a dedicated CSS file or extract to a Tailwind `@layer components` block                                  |
| `.btn-export` — button padding, font-size, border-radius, color                                                                    | `water_tool.css` | Move to Tailwind utilities on the `<a class="btn-export">` element in `index.html.erb`; the element retains enough structure that inline Tailwind replaces the rule cleanly                                   |
| `.table-header` — `overflow: hidden`                                                                                               | `water_tool.css` | Add `overflow-hidden` Tailwind class to the `.table-header` div in `index.html.erb`                                                                                                                           |


