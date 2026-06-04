# Data Table — Architecture & Reference

The data table is a core feature of the app. This document captures design decisions, behavioral expectations, and key patterns. For row selection and export architecture, see `docs/table_reboot.md`.

---

## Design Decisions

### Sort behavior
- **3-state cycle:** unsorted (↕) → ascending (↑) → descending (↓) → unsorted. Third click drops `sort`/`direction` params entirely, restoring default `pws_name ASC` order.
- **`NULLS LAST` always** — on both ASC and DESC. PostgreSQL defaults to `NULLS FIRST` for DESC, which puts missing data at the top. Users expect missing data out of the way regardless of sort direction.
- **Tiebreaker:** `pws_name ASC` appended to every `ORDER BY` (skipped when `pws_name` is the primary sort column). Matches legacy behavior where the DataTables array was pre-sorted by name before client-side sorting.
- **SQL injection guard:** `SORTABLE_COLUMNS` allowlist in `HomeController` — only these column names are permitted in `ORDER BY`. Does not control display order.

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

Badge and export behavior:

| State | Badge | Export sends |
|---|---|---|
| All mode, nothing excluded | `All` | Filter params only |
| All mode, some excluded | `total − excluded.size` | Filter params + `exclude_pwsids[]` |
| None mode, some included | `included.size` | `pwsids[]` |
| None mode, nothing included | `0` + button grayed out | no-op |

Export always uses POST (CSRF token, avoids URL length limits). The server has two paths: `apply_filters + where.not(pwsid: excluded)` vs `where(pwsid: included)`. The exclusion model was chosen because it keeps payloads small at every realistic threshold — a user unchecking 3 of 5,000 rows sends 3 IDs, not 4,997.

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
app/views/home/_table.html.erb           ← table partial (Turbo Frame + all table HTML)
app/helpers/home_helper.rb               ← table_sort_link, col_highlight, aria_sort, fmt_* helpers
app/controllers/home_controller.rb       ← #table action, SORTABLE_COLUMNS, ORDER BY logic
app/javascript/controllers/
  table_frame_controller.js              ← preserves horizontal scroll across Turbo Frame reloads
  filter_controller.js                   ← reloads data-table Turbo Frame on filter change
  export_controller.js                   ← builds and submits POST form on export
  row_selection_controller.js            ← checkbox state, badge, export button disabled state
  selection_state.js                     ← shared selection state module (mode, excluded/included Sets)
spec/requests/home_spec.rb               ← request specs for the table action
docs/table_reboot.md                     ← row selection & export architecture
```

---

## Key Patterns

### Sort link (`home_helper.rb`)
Cycles unsorted → asc → desc → unsorted. Third click drops `sort`/`direction` params. Icon is stacked ▲▼ triangles — active direction is `text-gray-600`, inactive is `text-gray-300`. Only the label underlines on hover via Tailwind `group`/`group-hover:underline` (not the icon).

### SORTABLE_COLUMNS (`home_controller.rb`)
```ruby
SORTABLE_COLUMNS = %w[
  pws_name pwsid stusps counties gw_sw_code source_water_protection_code
  owner_type primacy_type is_wholesaler is_school_or_daycare symbology_field
  area_sq_miles open_health_viol
].freeze
```

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

- **Remaining sortable columns** — violation counts, demographics, EJ, funding, watershed require joins; not yet in `SORTABLE_COLUMNS`
- **"Public Water Utilities in [Place]" dynamic title** — `filter_controller.js` already holds `params.place_name`; `.geo-filter` spans exist in `index.html.erb` and `_filter_menus.html.erb` but nothing writes to them yet. Preferred approach: add a Stimulus value + callback to `filter_controller.js` that updates all `.geo-filter` spans on place filter change
- **Spec gaps** — nil numeric/string render as `"—"` not fully covered; full column-header sweep spec not written
- **`water_tool.css` migration** — several table layout rules (`#container-table`, `turbo-frame#data-table`, `.table-header`, `.btn-export`) still use legacy CSS; migrate to Tailwind utilities when deprecating that file
