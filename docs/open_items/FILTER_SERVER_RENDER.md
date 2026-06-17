# Server-Render Filter UI from URL State

## Context

### What

On full page load, **filter menus** and the **manage-columns panel** restore state from the
same `encoded=` URL blob — but through different mechanisms:

| UI | Reload wiring | Who renders control state |
|---|---|---|
| **Filters** | `filter_controller.js#restoreFromUrl` → `#restoreDomState` | **JavaScript** walks the DOM and sets radios, checkboxes, sliders, panel expand/collapse |
| **Columns** (target) | `HomeController#index` → `ColumnRegistry` → ERB | **Rails** renders panel list order + checkboxes from decoded blob |
| **Table** (both) | `HomeController#table` → `apply_filters` / `ColumnRegistry.visible` | **Rails** — always server-side |

`FilterState` is an in-memory mirror of URL filter params for building requests. It is not a
separate source of truth. **Data filtering is server-authoritative in both cases.**

### Why

This split is accidental, not intentional architecture.

Filters grew incrementally: `app/views/home/_filter_menus.html.erb` renders static shells with
default values; `filter_controller.js` owns a parallel `FILTERS` registry (~40 control
definitions) that maps param names to DOM element IDs. When `encoded=` shipped, JS hydration
was the fastest path — `HomeController#index` never gained `@filter_state` for ERB.

Columns stayed small (~70 items, one registry in `ColumnRegistry`). The manage-columns panel
is server-renderable from decoded state — idiomatic Hotwire (URL → controller → HTML).

**Documented today (partial):** `docs/decisions/URL_MANAGEMENT.md` notes the
`restoreFromUrl()` exception on initial load. It does **not** explain the filters vs columns
split or the long-term direction. This doc fills that gap.

---

## Discovery

### What filters do today

**Apply (normal use):**
```
User clicks Apply
  → #collectFilters (read DOM)
  → FilterState.set
  → encoded= blob in URL (#syncToUrl)
  → filters:changed → map + table Turbo visits with encoded param
  → server decodes → apply_filters → correct rows
```

**Full page load / shared URL:**
```
GET /?encoded=...
  → index renders filter menus at static defaults (no params in ERB)
  → filter_controller#connect → #restoreFromUrl
  → decode blob → #restoreDomState (FILTERS switch per control type)
  → FilterState.set → reload table + stats frames
```

**Key files:**
- `app/javascript/controllers/filter_controller.js` — `#collectFilters`, `#restoreDomState`, `FILTERS`
- `app/views/home/_filter_menus.html.erb` — static menu HTML
- `app/filters/filter_registry.rb` — server-side param permit list (`config/filters.yml`)
- `app/controllers/home_controller.rb` — `decoded_state` for `/table`, not passed to `index` views

### What columns do (target pattern)

**Apply:**
```
Show Columns
  → read draft DOM → write complete column state into encoded blob
  → Turbo.visit /table with encoded param
```

**Full page load:**
```
GET /?encoded=...
  → HomeController#index decodes blob once
  → ColumnRegistry parses column state (order + visibility)
  → ERB renders panel; /table renders headers from same parse
```

**Key files (feat branch / in progress):**
- `app/columns/column_registry.rb` — `parse_keys`, `visible`, `panel_groups`
- `app/views/home/_manage_columns_list.html.erb`
- `app/javascript/controllers/manage_columns_controller.js` — draft + serialize only

### Why filters are the outlier

1. **Historical** — filter ERB was structural shells; JS registry became source of truth for wiring.
2. **Scale** — ~128 possible params, many control types (radio, multi-checkbox, nested subcat
   panels, histogram sliders, place autocomplete). Server-rendering each from state is a large
   touch surface.
3. **No index wiring** — `index` never receives `@filter_state`; no ViewComponents read decoded
   params today.
4. **It works** — shared URLs restore filters correctly; only the *mechanism* is non-idiomatic.

Columns should **not** copy the filter hydration pattern.

---

## Long-term refactor: wire filters like columns

### Case for refactoring

| Benefit | Detail |
|---|---|
| **Single decode path** | Controller decodes `encoded=` once; views and `/table` consume the same object |
| **Idiomatic Hotwire** | URL → server → HTML; Stimulus for interaction and draft only |
| **Delete duplicate registry** | `FILTERS` in JS mirrors `config/filters.yml` / `FilterRegistry` — two places to update when adding a filter |
| **Remove `#restoreDomState`** | ~200 lines of fragile DOM-by-ID restore logic |
| **Testability** | Request specs assert filter control state from HTML on `GET /` with `encoded=` — no browser required |
| **Consistency** | New contributors learn one pattern for all URL-driven UI |
| **Progressive enhancement** | Menus reflect URL state before JS connects (minor; JS still needed for Apply/sliders) |

### Case against / defer

| Cost | Detail |
|---|---|
| **Large scope** | Every filter control type needs ERB or ViewComponent to read `@filter_state` |
| **Histogram sliders** | May still need Stimulus to set handle positions even if server passes min/max values |
| **Place autocomplete** | Display name + geoid may need JS coordination |
| **No user-visible bug today** | Refactor is maintainability and convention, not broken share links |
| **Opportunistic timing** | Do when adding filters or touching `_filter_menus.html.erb` heavily — not blocking column work |

**Config storage change (YAML → DB, admin UI, etc.):** If filter/column definitions move off static YAML,
server-render becomes more important — not less. Registries become the single runtime source; views
read them per request. Extending JS `#restoreDomState` against a new config backend means maintaining
a second sync path. Plan this refactor alongside any config migration; do not deepen the JS restore
pattern first.

### Would behavior be the same?

**Yes, for users.** Shared URLs, Apply, Reset, badges, map/table data, and exports should
behave identically if the refactor is done correctly.

| Scenario | Today | After server-render |
|---|---|---|
| Apply filter | DOM → blob → server filters data | Same |
| Shared URL, new tab | JS hydrates menus, reloads frames | Menus correct in first HTML paint; frames still reload on connect (or server includes initial frame src) |
| Reset filter menu | DOM + blob update | Same |
| Badge counts | From `FilterState` after Apply | From decoded state or same `FilterState` after connect |
| No JS / slow JS | Menus show defaults until JS runs | Menus show URL state immediately ✓ (improvement) |

**Internal differences only:** delete `#restoreDomState`; add controller helper +
view helpers; possibly slim `FILTERS` to interaction-only metadata (not restore).

### Suggested end state

```
encoded= blob (filters + columns)
       ↓
HomeController#decoded_state (once)
       ↓
       ├── index: @filter_state → _filter_menus.html.erb (server render)
       │         @column_state  → _manage_columns_list.html.erb (server render)
       └── table/map/export: filter_params + ColumnRegistry (unchanged)
```

`filter_controller.js` keeps: Apply, `#collectFilters` (or form submit), `#syncToUrl`,
badge updates, stats/table frame reload, slider interaction. Loses: `#restoreDomState`.

---

## Implementation Guide

**Status: not started. Do not block column drag-and-drop or blob shape work.**

### Phase 1 — Foundation
- [ ] Add `HomeController#index` assignment: `@filter_state = decoded_state["filters"] || {}`
- [ ] Add helper or ViewComponent API: `filter_checked?(param, value)`, `filter_range_value(param, :min)`, etc.
- [ ] Request spec: `GET /` with `encoded=` → assert one radio, one checkbox, one range render correctly in HTML

### Phase 2 — Control types (incremental)
- [ ] Radio filters (water source)
- [ ] Boolean checkboxes
- [ ] Multi-select groups (owner type, etc.)
- [ ] Range / subcat panels (hardest — may keep partial JS for slider handles)
- [ ] Place filter (hidden geoid + display name from state)

### Phase 3 — Remove JS restore
- [ ] Delete `#restoreDomState` and restore-only entries in `FILTERS`
- [ ] `#restoreFromUrl` becomes: `FilterState.set`, frame reloads only (or drop if frames get server `src`)
- [ ] Update `docs/decisions/URL_MANAGEMENT.md` — remove "exception" language

### Related work (separate tracks)
- **Column blob shape** — full panel order + visibility in `encoded` blob; server `panel_groups`.
  See drag-and-drop branch / `DRAG_DROP_SORTABLE_JS.md`.
- **Do not** solve column sync by moving column panel restore into JS.

---

> **Cleanup:** Delete this file when filter menus are server-rendered from URL state and
> `#restoreDomState` is removed. Reference the closing PR in the commit message.
