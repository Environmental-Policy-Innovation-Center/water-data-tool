# Data Table — Architecture & Reference

The data table is a core feature of the app. This document captures design decisions, behavioral expectations, and key patterns. For row selection and export architecture, see `docs/table_reboot.md`.

---

## Design Decisions

### Sort behavior
- **3-state cycle:** unsorted (↕) → ascending (↑) → descending (↓) → unsorted. Third click drops `sort`/`direction` params entirely, restoring default `pws_name ASC` order.
- **Sort persists through resets.** Resetting filters (individual menu or Reset All) and resetting columns both preserve the active sort. Sort is an independent user preference — orthogonal to both filter state and column visibility. The only way to clear sort is to cycle back to unsorted via the column header.
- **`NULLS LAST` always** — on both ASC and DESC. PostgreSQL defaults to `NULLS FIRST` for DESC, which puts missing data at the top. Users expect missing data out of the way regardless of sort direction.
- **Tiebreaker:** `pws_name ASC` appended to every `ORDER BY` (skipped when `pws_name` is the primary sort column). Matches legacy behavior where the DataTables array was pre-sorted by name before client-side sorting.
- **SQL injection guard:** `SORTABLE_COLUMNS` allowlist in the `Sortable` concern (`app/controllers/concerns/sortable.rb`) — only these column names are permitted in `ORDER BY`. Does not control display order.

### Nil display
- All nil DB values render as `"—"` (em dash) in every cell. Never `"NA"`, `"N/A"`, `0`, or empty string.
- `0` and `""` are misleading — they imply a real value, not absence of data.
- Booleans: `"Yes"` / `"No"` / `"—"` for nil. A nil wholesaler flag is not the same as `false`.

### Sortable columns
All data columns are sortable. The EPA Facility Report column is not (it renders a link, not a sortable value). Violation counts, demographics, EJ, funding, and watershed columns are not yet sortable — they require joining associated tables in the `ORDER BY` and are deferred.

### Row selection & export
Uses the **Inversion of Selection** (Implicit/Explicit Selection State) pattern — industry standard for large paginated datasets (Salesforce, AWS Console, HubSpot).

Two modes, each backed by a `Set` of PWSID strings (O(1) lookup, guaranteed uniqueness):

| Mode | Active when | Set tracks | `isAllChecked()` |
|---|---|---|---|
| **All mode** | Default, after Select All, after filter change | `excluded` — individually unchecked IDs | `excluded.size === 0` |
| **None mode** | After Deselect All | `included` — individually checked IDs | always `false` |

State transitions: `deselectAll()` → none mode · `selectAll()` or filter change (`clear()`) → all mode · `toggle(id)` → adds/removes from the active set.

The toggle button (Select All / Deselect All) drives **mode only** (Axis 1: all ↔ none). Individual row checks fill the active set (Axis 2: empty ↔ non-empty). The 4 export states above are the 2×2 product of these two axes — the button never sees Axis 2 directly, but the export payload builder always does.

Badge and export behavior:

| State | Badge | Export sends |
|---|---|---|
| All mode, nothing excluded | `All` | Filter params + search + sort/direction |
| All mode, some excluded | `total − excluded.size` | Filter params + search + sort/direction + `exclude_pwsids[]` |
| None mode, some included | `included.size` | `pwsids[]` + sort/direction |
| None mode, nothing included | `0` + button grayed out | no-op |

Export always uses POST (CSRF token, avoids URL length limits). The server has two paths: `apply_filters + apply_search + where.not(pwsid: excluded)` vs `where(pwsid: included)`. Both paths apply the current sort order. The exclusion model was chosen because it keeps payloads small at every realistic threshold — a user unchecking 3 of 5,000 rows sends 3 IDs, not 4,997.

**Sort/search state in the DOM.** The server renders current sort/direction into a `#table-query-state` span inside the frame on every frame navigation. `export_controller.js` reads `data-sort`/`data-direction` from this span and reads the active search term from `SearchState.get()` directly; `filter_controller.js` reads sort/direction after each frame load to sync them into the page URL. See `docs/decisions/URL_MANAGEMENT.md` for the full URL state design.

### Manage Columns (`cols=`)

Column visibility and display order persist in the `cols=` URL param (comma-separated keys). Pinned columns (`:check`, `:pws_name`) always render first regardless of `cols=`.

| `cols=` value | Table | Manage Columns panel |
|---|---|---|
| Absent | All columns, YAML order | All checked, YAML/category order |
| Present | Listed keys in param order | Checked keys in param order (category blocks merge when consecutive) |
| Empty string | Pinned only | Pinned only (all selectable unchecked) |

**Apply model:** The panel is a draft while open. Drag and checkbox changes do not update the table or URL until **Show Columns**. **Reset** restores the server `<template>` (YAML default), checks all boxes, clears `cols=`, and reloads the table frame.

**Reload behavior:** On full page load, `HomeController#index` sets `@visible_col_keys` and `@panel_groups = ColumnRegistry.panel_groups(keys:)` so the panel list matches `cols=` without JS restore. Close/reopen on the same page keeps DOM draft order (no re-render).

**Show Columns / Reset URL build:** Uses `FilterState.toUrlParams()` plus `cols` (not server-rendered hidden filter inputs) so current filters are preserved. See `docs/URL_MANAGEMENT.md` for the filters-vs-columns architecture split.

**Drag-and-drop:** SortableJS — outer list reorders category blocks; inner lists reorder within a category only. Order encoded in `cols=` on submit.

---

## Notable Differences from Legacy (PHP + DataTables)

| Topic | Legacy | Current |
|---|---|---|
| Sort engine | Client-side DataTables (all rows in memory) | Server-side SQL (`ORDER BY` in `HomeController`) |
| NULL handling | Coerced to `0` (numeric) or `""` (string) before sorting | Sort against DB NULL with `NULLS LAST` |
| NULL display | `0` or empty string | `"—"` via `fmt_*` helpers |
| Boolean display | `true` / `false` | `"Yes"` / `"No"` / `"—"` for nil |
| Sort states | 3-state (DataTables default) | 3-state — third click clears params |
| Tiebreaker | Implicit (array pre-sorted by `pws_name ASC`) | Explicit `pws_name ASC` appended to every `ORDER BY` |
| Pagination | Client-side (all rows loaded) | Server-side via Pagy |
| Search | Client-side global filter across all loaded rows and columns | Server-side `ILIKE` on `pws_name`, `pwsid`, `stusps`, `counties` only |

---

## Key Files

```
app/views/home/_table.html.erb              ← table partial (Turbo Frame + all table HTML)
app/helpers/home_helper.rb                  ← table_sort_link, col_highlight, aria_sort, fmt_* helpers
app/controllers/home_controller.rb          ← #index (@panel_groups), #table action
app/columns/column_registry.rb              ← visible, panel_groups, parse_keys
app/views/home/_manage_columns_list.html.erb
app/controllers/concerns/sortable.rb        ← SORTABLE_COLUMNS, TABLE_JOINS, sort/search logic (shared by Home + Exports)
app/javascript/controllers/
  table_frame_controller.js                 ← preserves horizontal scroll across Turbo Frame reloads
  table_search_controller.js               ← debounced search input; reads/writes SearchState; handles filter:reset-all
  filter_controller.js                      ← reloads data-table Turbo Frame on filter change
  manage_columns_controller.js              ← column panel draft, SortableJS, Show Columns apply
  export_controller.js                      ← builds and submits POST form on export
  row_selection_controller.js               ← checkbox state, badge, export button disabled state
  selection_state.js                        ← shared selection state module (mode, excluded/included Sets)
spec/requests/home_spec.rb                  ← request specs for the table action
docs/table_reboot.md                        ← row selection & export architecture
```

---

## Key Patterns

### Table Search (`table_search_controller.js`)

The search box sits in the filter tab bar (`#filter-tabs`), visible only in table mode (`hidden group-[.table-mode]/map:flex`). It searches server-side via `Sortable#apply_search` across four columns:

| Column | What it covers |
|---|---|
| `pws_name` | Utility name |
| `pwsid` | Utility ID (prefix and substring match) |
| `stusps` | 2-letter state code (`TX`, `OR`, etc.) |
| `counties` | County name text |

**Behavior:**
- **2-character minimum** — input is ignored until the term reaches 2 characters. Clearing the field back to 0 fires immediately.
- **300ms debounce** — standard delay; only one request fires after the user stops typing.
- **Applied immediately** — no submit button. On debounce expiry, `SearchState` is updated, `syncToUrl()` encodes it into `?encoded=` as a top-level `search` key alongside filter params, and the `data-table` Turbo Frame reloads.
- **Persists through filter Apply** — search lives in `SearchState`, separate from `FilterState`, so clicking Apply on a filter menu never touches it.
- **Cleared by Reset All** — `filter:reset-all` event is handled by `table_search_controller`, which clears the DOM input and calls `SearchState.clear()` before `apply()` rebuilds state.
- **Persists across map/table toggle** — search is committed to the URL and FilterState on debounce; switching to the map and back returns the same table state. The map endpoint (`home#map`) does not call `apply_search`, so map dot visibility is unaffected by the search term.
- **Combined with filters narrows further** — `HomeController#table` runs `apply_filters` first, then `apply_search` on the resulting scope. A search for "Springfield" while filtered to Oregon will only match Springfield-named systems in Oregon. Zero results is expected and correct — the browser's native input clear (×) or Reset All provide exit paths. The table caption (`sr-only`) describes the active search term for screen readers.
- **Exports** — `export_controller.js` reads `SearchState.get()` and appends it as a flat `search` param. `ExportsController` reads `params[:search]` and applies `apply_search` to the export scope.

### Sort link (`home_helper.rb`)
Cycles unsorted → asc → desc → unsorted. Third click drops `sort`/`direction` params. Icon is stacked ▲▼ triangles — active direction is `text-gray-600`, inactive is `text-gray-300`. Only the label underlines on hover via Tailwind `group`/`group-hover:underline` (not the icon).

### SORTABLE_COLUMNS (`app/controllers/concerns/sortable.rb`)
Derived from `FilterRegistry.sortable_columns` — a hash of `column_name → table_name`. Both `HomeController` and `ExportsController` include `Sortable` to share this allowlist and the `order_clause` / `apply_sort_join` / `apply_search` methods.

### Turbo Frame loading
The table renders inside `<turbo-frame id="data-table">`. `filter_controller.js` calls `Turbo.visit("/table?#{FilterState.toUrlParams()}", { frame: "data-table" })` on filter change or view toggle. The `/table` route hits `HomeController#table`, which renders `_table.html.erb`.

`table_frame_controller.js` intercepts `turbo:before-frame-render` and restores `scrollLeft` in the same microtask as the DOM swap — no visible horizontal scroll flash.

### Format helpers (nil → `"—"`)
All live in `home_helper.rb` and return `"—"` for nil:

| Helper | Output |
|---|---|
| `fmt_str(val)` | String presence; `"—"` for nil/blank |
| `fmt_bool(val)` | `"Yes"` / `"No"` / `"—"` for nil |
| `fmt_num(val)` | Integer with thousands separator |
| `fmt_dec(val, precision: 2)` | Float with delimiter |
| `fmt_pct(val, precision: 2)` | Percentage |
| `fmt_cur(val, precision: 0)` | Currency |

---

## Open Items

- **Preload optimization** — `HomeController#table` hardcodes all 6 association preloads regardless of which columns are visible. Fix is `@columns.filter_map(&:source).reject { |s| s == :pws }.uniq`. Low-priority cleanup; actual gain is small because preloads cover only 25 rows and PostgreSQL's buffer cache serves repeated queries from memory. See `docs/table_reboot.md` for full context.
- **Remaining sortable columns** — violation counts, demographics, EJ, funding, watershed require joins; not yet in `SORTABLE_COLUMNS`
- **Spec gaps** — nil numeric/string render as `"—"` not fully covered; full column-header sweep spec not written
- **`water_tool.css` migration** — several table layout rules (`#container-table`, `turbo-frame#data-table`, `.table-header`, `.btn-export`) still use legacy CSS; migrate to Tailwind utilities when deprecating that file
