# Data Table — Architecture & Reference

The data table is a core feature of the app. This document captures design decisions, behavioral expectations, and key patterns. For row selection and export architecture, see `docs/table_reboot.md`.

---

## Design Decisions

### Sort behavior
- **3-state cycle:** unsorted (↕) → ascending (↑) → descending (↓) → unsorted. Third click drops `sort`/`direction` params entirely, restoring default `pws_name ASC` order.
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

**Sort/search state in the DOM.** Sort header clicks and the search form navigate the `data-table` Turbo Frame only — they do not update `window.location`, and `FilterState` only tracks filter panel state. The server renders current sort/direction/search into a `#table-query-state` span inside the frame (re-rendered on every frame navigation). `export_controller.js` reads from this span so exports always match what the user sees in the table.

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

---

## Key Files

```
app/views/home/_table.html.erb              ← table partial (Turbo Frame + all table HTML)
app/helpers/home_helper.rb                  ← table_sort_link, col_highlight, aria_sort, fmt_* helpers
app/controllers/home_controller.rb          ← #table action
app/controllers/concerns/sortable.rb        ← SORTABLE_COLUMNS, TABLE_JOINS, sort/search logic (shared by Home + Exports)
app/javascript/controllers/
  table_frame_controller.js                 ← preserves horizontal scroll across Turbo Frame reloads
  filter_controller.js                      ← reloads data-table Turbo Frame on filter change
  export_controller.js                      ← builds and submits POST form on export
  row_selection_controller.js               ← checkbox state, badge, export button disabled state
  selection_state.js                        ← shared selection state module (mode, excluded/included Sets)
spec/requests/home_spec.rb                  ← request specs for the table action
docs/table_reboot.md                        ← row selection & export architecture
```

---

## Key Patterns

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

- **Column reordering** — drag-and-drop will be server-side via `cols=` param (consistent with visibility). `visible_columns` in `HomeController` currently respects `cols=` for filtering only; it will need updating to also respect the param's key order rather than always deferring to YAML order.
- **Preload optimization** — `HomeController#table` hardcodes all 6 association preloads regardless of which columns are visible. Fix is `@columns.filter_map(&:source).reject { |s| s == :pws }.uniq`. Low-priority cleanup; actual gain is small because preloads cover only 25 rows and PostgreSQL's buffer cache serves repeated queries from memory. See `docs/table_reboot.md` for full context.
- **Remaining sortable columns** — violation counts, demographics, EJ, funding, watershed require joins; not yet in `SORTABLE_COLUMNS`
- **"Public Water Utilities in [Place]" dynamic title** — `filter_controller.js` already holds `params.place_name`; `.geo-filter` spans exist in `index.html.erb` and `_filter_menus.html.erb` but nothing writes to them yet. Preferred approach: add a Stimulus value + callback to `filter_controller.js` that updates all `.geo-filter` spans on place filter change
- **Spec gaps** — nil numeric/string render as `"—"` not fully covered; full column-header sweep spec not written
- **`water_tool.css` migration** — several table layout rules (`#container-table`, `turbo-frame#data-table`, `.table-header`, `.btn-export`) still use legacy CSS; migrate to Tailwind utilities when deprecating that file
