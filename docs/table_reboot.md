# Table Row Selection & Export

> **Temporary doc — branch `117-feat-select-table-rows`.** Delete before merge. Permanent architecture reference: `docs/DATA_TABLE.md`.

**Status: 811 examples, 0 failures. CI green.**
**Complete:** row selection & export, column-filtered CSV, `cols=` URL persistence, copy utility ID to clipboard.
**Not blocking merge:** §3 preload, §4 BWN filter (product decision), §5 drag-and-drop, custom checkbox SVGs.

---

## Before Merging

### Manual verification
- [ ] **Sort preserved on export** — sort by a non-default column → Export → CSV rows match sort order.
- [ ] **Export button state** — default = green; Deselect All = gray; Select All = green restored.
- [ ] **CSV column filtering** — pick a column subset in Manage Columns → Export CSV → only those headers appear.
- [ ] **cols= survives filter change** — set custom columns → apply a filter → Export → CSV still uses selected columns (not all columns).
- [ ] **Copy utility ID** — hover a row → copy icon appears → click → PWSID copied to clipboard → icon swaps to checkmark for 2s.
- [ ] **Manage Columns panel state** — select a subset → close panel → reopen → checkboxes reflect selection, not reset to all.
- [ ] **`bin/ci` passes** — run before opening PR.

### Non-blocking open items
- **§3 Preload optimization** — one-liner in `HomeController#table`: `preloads = @columns.filter_map(&:source).reject { |s| s == :pws }.uniq`. Only affects table render, not the export path.
- **§4 BWN filter** — UI-disabled with `(data unavailable)`. Backend wired. Waiting on product decision: re-enable as-is, or add tooltip about variable reporting windows across states.
- **§5 Drag-and-drop column reordering** — drag handles visible but not wired. See SortableJS documentation.
- **Custom checkbox SVGs** — design assets in `app/assets/svgs/`, not wired. Full wiring guide: `/tmp/todo_add_remaining_svgs.md`.

---

## Known Concerns / Acknowledged Technical Debt

These were reviewed and deliberately deferred — flagging here so a PR reviewer doesn't re-raise them as surprises.

**`to_csv_stream` plucks all sorted IDs before streaming**
`@scope.pluck(:pwsid)` runs once inside the Enumerator block (lazy — executes when streaming starts), then `each_slice` batches in Ruby. Peak memory is ~1.6MB for a full 160k-row export. `pws_name` and most other sortable columns are not indexed, so an OFFSET-based alternative would require a full table scan per batch — the single-pluck approach is strictly better for this schema.

**`selection_state.js#clear` aliases `selectAll`**
`export const clear = selectAll` — a future reader expecting `clear()` to empty the selection will be surprised. The alias exists because `filter_controller.js` calls `SelectionState.clear()` to reset selection on filter change, which should restore "all selected" not "nothing selected". Intentional but non-obvious.

**`visible(keys:)` called inconsistently with Array vs Set**
`HomeController` converts `parse_keys` output to a `Set` before passing to `visible`; `ExportsController` passes the `Array` directly. Both work (`Array#include?` and `Set#include?` share the same interface), but alignment would remove the inconsistency. At ~100 columns the O(n) vs O(1) difference is imperceptible.

**`colsInput` Stimulus target still declared in `manage_columns_controller.js`**
The hidden `<input name="cols">` in `index.html.erb` is still needed for the form-submit approach. If the form-based column submission is ever replaced by a pure `Turbo.visit`, this target declaration and the `colsInputTarget` references in `serializeCols` must be removed together — otherwise Stimulus throws a missing-target error on connect.

---

## What Was Built (PR Summary)

### Row selection & export
- **Selection state model** (`selection_state.js`) — all-mode with `excluded` Set / none-mode with `included` Set. Handles paginated datasets without server round-trips. `clear()` resets to all-mode on filter change.
- **Row checkboxes** — leftmost sticky column, all checked by default on load/filter change.
- **Select All / Deselect All** — above the table, outside the Turbo Frame so they survive navigation.
- **Export badge** — shows `All`, numeric count (accounting for exclusions in all-mode), or nothing when selection is empty.
- **Export button** — green when rows selected; gray + `cursor-not-allowed` + `aria-disabled` when empty. `--color-brand-action: #67a25e` CSS token in `application.css`.
- **Export via POST** — CSRF-safe form built dynamically in `export_controller.js`. Reads sort/search from `#table-query-state` (server-rendered in the Turbo Frame). Three branches: all checked → filter params; all-mode with exclusions → filter params + `exclude_pwsids[]`; none-mode → explicit `pwsids[]`.
- **Streaming CSV + GeoJSON** — lazy Enumerator; pluck + batched raw SQL, no AR objects materialised. Shared `ASSOCIATION_JOINS` constant.

### Column-filtered CSV export
- **`ColumnRegistry.parse_keys`** — single canonical parser for the `cols=` param: `nil` = all, `""` = pinned only, `"a,b"` = explicit set. Both `ExportsController` and `HomeController` delegate to it.
- **`to_csv_stream(cols:)`** — `_pwsid_idx` sentinel prepended to every batch query for sort-order reconstruction; stripped with `row.except("_pwsid_idx").values` before streaming.
- **`cols=` URL persistence** — `manage_columns_controller.js#serializeCols` calls `history.replaceState` immediately (Turbo frame form submissions do not update `window.location`). `filter_controller.js#preserveViewParams` carries `cols`, `sort`, `direction` through all filter changes.

### Manage Columns panel
- **3 ViewComponents** — `PinnedRowComponent`, `CategoryHeaderRowComponent`, `ColumnRowComponent`. Categories from `columns.yml`.
- **Collapse/expand** — `data-category-key` on each header button; chevron at `-rotate-90` = collapsed (default). `#setCategoryExpanded` is the single toggle point used by open, collapse-all, and reset.
- **Category checkbox** — toggles all children; shows indeterminate state via `#updateCategoryState`.
- **Panel sizing** — `maxHeight` computed dynamically in `#open()` from the distance between the button bottom and the `[aria-label="Table navigation"]` footer.

### Copy utility ID to clipboard
- **`:copy` format type** — `pwsid` column declared as `format: copy` in `columns.yml`; `render_table_cell` renders a value + icon button. Button title uses `col.label` so any future `:copy` column gets the right tooltip.
- **`clipboard_controller.js`** — `navigator.clipboard.writeText` with `.catch(() => {})` to silence permission-denial rejections; swaps copy → check icon for 2s on success.

---

## Architecture: `cols=` end-to-end

1. User picks columns → `serializeCols` → `#updateUrl` writes `cols=a,b` into `window.location` via `history.replaceState`; form submits to `/table?cols=...` reloading the Turbo frame.
2. Filter changes → `#syncToUrl` calls `#preserveViewParams` to carry `cols`, `sort`, `direction` before overwriting the URL with new filter params. `#visitTableFrame` does the same before `Turbo.visit`.
3. Export click → `export_controller.js` reads `cols` from `window.location.search`, appends to POST body.
4. Server → `ColumnRegistry.parse_keys(params[:cols])` → array of keys → `to_csv_stream(cols:)` → `csv_columns(keys:)` → pinned columns always included + requested optional columns.
5. GeoJSON ignores `cols` — always exports all properties.

**The URL is the only state store. Nothing in localStorage/sessionStorage.**

**Critical:** `#updateUrl` in `serializeCols` is not redundant — Turbo frame form submissions do not update `window.location`. Removing it breaks both `export_controller` (reads `cols` from the URL) and `#syncCheckboxesFromUrl` (reads `cols` on panel open). This was a live regression on this branch.

---

## Key Files

```
app/javascript/selection_state.js                              ← selection state (all-mode / none-mode)
app/javascript/controllers/row_selection_controller.js         ← checkboxes, badge, export button state
app/javascript/controllers/export_controller.js                ← POST form builder (incl. cols=)
app/javascript/controllers/filter_controller.js                ← #preserveViewParams carries cols/sort/direction
app/javascript/controllers/manage_columns_controller.js        ← panel, col toggles, serializeCols + #updateUrl
app/javascript/controllers/clipboard_controller.js             ← copy-to-clipboard with icon swap
app/controllers/public_water_systems/exports_controller.rb     ← 3 export branches
app/controllers/home_controller.rb                             ← parse_cols_param, pinned_columns, visible_columns
app/controllers/concerns/sortable.rb                           ← SORTABLE_COLUMNS, TABLE_JOINS
app/columns/column_registry.rb                                 ← parse_keys, csv_columns(keys:), visible(keys:)
app/exporters/public_water_system_exporter.rb                  ← to_csv_stream(cols:), to_geojson_stream
app/helpers/home_helper.rb                                     ← render_table_cell (:copy, :link, :check, default)
app/assets/svgs/copy.svg, check.svg                            ← clipboard icons
app/components/manage_columns/                                 ← Pinned / CategoryHeader / ColumnRow components
app/views/home/index.html.erb                                  ← controller mounts, manage-columns panel
app/views/home/_table.html.erb                                 ← totalCount + table-query-state spans
spec/requests/exports_spec.rb
spec/exporters/public_water_system_exporter_spec.rb
spec/helpers/home_helper_spec.rb
```
