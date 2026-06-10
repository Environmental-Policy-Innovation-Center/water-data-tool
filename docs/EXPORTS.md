# Exports

Exports are delivered synchronously via streaming — the browser receives bytes as they are generated. No background job or polling is needed for the current implementation. See [Future Work](#future-work) for the async path if that ever becomes necessary.

---

## Endpoint

`POST /public_water_systems/export`

Export is always POST. GET was removed — GET silently breaks for large payloads (URL length limits), which is the exact problem POST solves. An export is an ephemeral action, not a shareable URL, so there is no bookmarking trade-off.

---

## Selection State Model

Row selection uses an **Inversion of Selection** (hybrid inclusion/exclusion) model — the same pattern used by Salesforce, AWS Console, and HubSpot for large paginated datasets.

| Mode | Meaning | Set in use |
|---|---|---|
| **All mode** | Every row implicitly selected. Unchecking adds an ID to `excluded`. | `excluded` Set |
| **None mode** | No rows selected. Checking adds an ID to `included`. | `included` Set |

`mode`, `excluded`, and `included` are the source of truth. `isAllChecked()` and `isAllMode()` are derived predicates, not state. Sets are used (not arrays) — O(1) membership testing and guaranteed uniqueness.

**Why the hybrid approach:** The server always receives the smallest possible representation of the user's intent. A user with 5,000 filtered rows who unchecks 3 sends 3 IDs (exclusion). A user who explicitly picks 3 rows sends 3 IDs (inclusion). Neither path requires sending thousands of IDs to describe a near-complete or near-empty selection.

---

## Three Export Paths

| Selection state | JS sends | Server behaviour |
|---|---|---|
| All mode, nothing excluded (`isAllChecked()`) | Filter params + search | `apply_filters` + `apply_search` |
| All mode, some excluded | Filter params + search + `exclude_pwsids[]` | Above + `where.not(pwsid: exclude_pwsids)` |
| None mode, rows checked | `pwsids[]` | `where(pwsid: pwsids)` |
| None mode, nothing checked | no-op | early return, no submission |

All three paths also send `sort`, `direction`, and `search` — read from a `#table-query-state` sr-only span rendered inside the Turbo Frame, which always reflects live state regardless of `window.location`.

Export is built via a dynamically constructed `<form>` (with CSRF token) that is submitted and immediately removed.

---

## Streaming: CSV

Uses the Rack body streaming pattern (`self.response_body = enumerator`). No AR objects are instantiated. No `Content-Length` is sent — the browser shows a live byte count.

**Two-phase approach (preserves sort order):**

1. **Phase 1 — sorted ID pluck:** `@scope.pluck(:pwsid)` captures pwsids in the user's requested sort order. The scope already has `apply_sort_join` + `ORDER BY` applied by the controller. (~2–4 MB of strings for the full dataset.)

2. **Phase 2 — batched raw SQL:** IDs are sliced into `BATCH_SIZE = 1000` chunks. Each chunk is fetched via a single raw SQL `SELECT` with all LEFT JOINs inline (`violations_summaries`, `demographics`, etc.). Rows within each batch are re-ordered by the phase-1 sequence. No AR objects are created.

**Exported columns** are determined by `ColumnRegistry.csv_columns(keys: visible_keys)` — only the columns visible in the user's current table view are exported. The `cols=` param is forwarded from the export form to the controller.

---

## Streaming: GeoJSON

Uses the same Rack body streaming pattern. Cursor-based batching keeps memory flat regardless of dataset size.

```sql
WHERE pws.pwsid > :last_seen_id ORDER BY pws.pwsid LIMIT 1000
```

Each batch advances the cursor. `ST_AsGeoJSON` + `jsonb_build_object` build each GeoJSON Feature inline in SQL — no Ruby serialization. The 100-arg PostgreSQL limit on `jsonb_build_object` is handled by slicing column pairs at 49 and merging chunks with `||`.

GeoJSON export is **full-fidelity** (all columns) regardless of the user's visible column set. It is consumed programmatically; `cols=` scoping applies to CSV only.

`ASSOCIATION_JOINS` is a shared frozen constant used by both CSV and GeoJSON queries. GeoJSON adds one extra join (`service_area_geometries`) for geometry data; CSV does not.

---

## Key Files

| File | Role |
|---|---|
| `app/javascript/selection_state.js` | All selection state logic (mode, excluded/included Sets, predicates) |
| `app/javascript/controllers/row_selection_controller.js` | Stimulus controller — checkboxes, badge, export button state |
| `app/javascript/controllers/export_controller.js` | Builds and submits POST form; reads `#table-query-state` for sort/search |
| `app/controllers/public_water_systems/exports_controller.rb` | `create` action — three selection paths + format dispatch |
| `app/exporters/public_water_system_exporter.rb` | `to_csv_stream` and `to_geojson_stream` streaming enumerators |
| `app/columns/column_registry.rb` | `csv_columns(keys:)` and `geojson_columns` — single source of truth for export schema |
| `app/views/home/_table.html.erb` | `#table-query-state` sr-only span (sort/search) + `data-row-selection-target="totalCount"` |
| `app/views/home/index.html.erb` | Select All / Deselect All buttons, Export button, row-selection controller mount |
| `spec/requests/exports_spec.rb` | All three export paths, sort ordering, search, filters |

---

## Future Work

**Async exports via SolidQueue** — for very large exports or slow connections, an async path would offload generation to a background job, store the file via ActiveStorage, and drive the UX with Turbo Frame polling. The synchronous streaming approach works well at current data volumes; this would only be warranted if Puma thread hold times or load balancer timeouts become a problem. See the archived design in `git log -- docs/EXPORT_IMPLEMENTATION.md` if needed.
