# Filter State Hydration — Current Fragility & Server-Render Refactor

> **Coordinate with the config consolidation (`docs/CONFIG_AUDIT.md`).** That effort
> introduces `config/fields.yml` as the single source of truth for filters — exactly
> the "single source of truth" this doc lists as a desired outcome. They converge:
> this refactor's core (server-render `_filter_menus.html.erb` from decoded state) and
> the manifest's final step (generate that ERB from `fields.yml`) are **the same work
> and should be done once.** When picking this up, build the server-rendered menu as a
> loop over the manifest rather than hand-converting the ~598 ERB lines. See
> CONFIG_AUDIT §7 (interaction) and §8 Phase 5 (the convergence). The manifest's
> back-end phases (0–4) are independent and ideally land first.

---

## Product Impact Summary

_Plain-language summary for non-technical stakeholders._

### What is the current risk?

The app has two systems that both need to know what filters a user has applied. When they
drift out of sync — which can happen silently during normal development — shared links break
in a specific, subtle way: **the data is still filtered correctly, but the filter menus don't
show the active filters visually.** A recipient of a shared link sees the right rows in the
table but has no indication of why — the filter panel looks empty. This is misleading and
erodes trust in shared links as a feature.

### How would I see this bug today?

1. Apply one or more filters in the app.
2. Copy the URL and open it in a new incognito window.
3. **Expected:** filter menus show the active filters highlighted/checked.
4. **At risk:** filter menus appear empty (all defaults), even though the data is filtered.

This bug does not currently exist — but the structure makes it one routine code change away
from appearing silently in production.

Specifically: every filter control in the HTML template has an `id="..."` attribute (e.g.
`id="has-source-water-protection"`, `id="min-groundwater-5yr"`). Those same ID strings are
hardcoded a second time in `app/javascript/controllers/filter_controller.js`, inside a
`FILTERS` constant that maps each ID to its filter param. The two locations must always agree:

| Location | Where the ID lives |
|---|---|
| `app/views/home/_filter_menus.html.erb` | `id="has-source-water-protection"` on the checkbox element |
| `app/javascript/controllers/filter_controller.js` | `{ id: "has-source-water-protection", param: "has_source_protection" }` in the `FILTERS` constant |

If a developer renames either — extracting a filter into a ViewComponent, changing an ID for
clarity, restructuring the template — without updating the other file, the restore silently
breaks for that filter. No error is thrown; the menu just shows at its default. The only way
to catch it is to manually test a shared URL.

### What else does the current approach cost?

| Problem | User-visible impact | Developer impact |
|---|---|---|
| Silent broken shared links | Recipient sees filtered data with no visual context | Hard to reproduce, hard to test |
| Filters defined in two places | None until they drift — then broken shared links | Every filter addition or rename must be made in both `config/filters.yml` and `filter_controller.js`; no automated check that they agree |
| No automated tests for shared URL restore | Bugs ship undetected until manual QA | No regression safety net |
| Shared links can't include which view (map vs. table) | Recipient always lands on map, even if sender was in table | Feature is deferred until this is fixed |

### What does the refactor enable?

| Outcome | Detail |
|---|---|
| **Reliable shared links** | Filter menus always reflect active filters visually on load |
| **Automated test coverage** | Regressions caught before shipping, not after |
| **Single source of truth for filters** | `config/filters.yml` defines a filter once; adding or changing a filter is one update, not two. The server and the UI are always in sync by construction. |
| **Simpler path to new filters** | Add an entry to `config/filters.yml`, wire the ERB — done. No parallel JS registry entry required, no risk of silent drift. |
| **`view=table` URL sharing** | Shared links land on the correct map or table view |
| **Faster, safer future filter work** | New filters follow one clear pattern with test coverage built in |

### How big is the effort?

Medium-to-large. The work is incremental — each filter control type can be done, tested, and
verified independently with no big-bang cutover. The app works correctly at every step.

The implementation and automated test writing can move quickly. The part that cannot be
automated away is **manual browser QA**: each filter control type must be visually verified
in the browser after it is updated (slider handle positions, dropdown expand/collapse state,
autocomplete display names). That verification is the primary cost in human time and sets
the pace of the work.

---

## What This Is About

On full page load (including shared URLs), filter menus and the manage-columns panel both
restore their visual state from the same `encoded=` URL blob — but through different mechanisms.
Filters are hydrated by **JavaScript** after load; columns are rendered by **Rails** before load.

This split is accidental. It is the source of ongoing maintenance debt, a known test coverage
gap, and the reason that adding `view=` (section state) cleanly to the URL is deferred.

This document covers: why the split exists, how fragile the current JS path is, what the
correct architecture looks like, and a concrete implementation plan.

---

## Current State vs. Target State

| | Filter Menus | Manage-Columns Panel |
|---|---|---|
| **Today** | Static HTML shells + JS hydrates state after load | Server-rendered from decoded blob |
| **Target** | Server-rendered from decoded blob | Server-rendered from decoded blob (unchanged) |
| **Who restores state** | `filter_controller.js#restoreDomState` | `HomeController#index` → ERB |
| **Testable with request specs?** | No — behavior is client-side JS | Yes |
| **Conventional Hotwire?** | No | Yes |

The table data (rows, counts, map pins) is server-filtered in both cases and always has been.
This is only about how the **filter menu UI** visually reflects the current filter state.

The principle the target state enforces: **JS handles interaction; Rails handles initial state.**
Stimulus is for wiring up events, applying/resetting, and slider drag behavior —
not for reconstructing UI state that the server already knows from the URL.

---

## Why the Split Exists

Filters grew incrementally. `_filter_menus.html.erb` renders static HTML shells with default
values; `filter_controller.js` accumulated a parallel `FILTERS` registry (~40 control
definitions) that maps param names to DOM element IDs. When the `encoded=` blob shipped,
JS hydration was the fastest path — `HomeController#index` never gained `@filter_state` for ERB.

Columns stayed small (~70 items, one registry in `ColumnRegistry`). The manage-columns panel
was server-renderable from decoded state — the idiomatic Hotwire approach.

Columns should **not** have copied the filter hydration pattern. They didn't. Filters should
be brought up to match columns.

---

## Why the Current Implementation Is Fragile

### 1. Hardcoded DOM IDs with no enforcement

`#restoreDomState` walks the DOM by hardcoded element IDs — `getElementById("has-source-water-protection")`,
`getElementById("min-groundwater-5yr")`, etc. These IDs are static strings that must match
exactly between `_filter_menus.html.erb` and the `FILTERS` constant in `filter_controller.js`.

If a developer renames an element ID in ERB (template refactor, ViewComponent extraction,
etc.) without updating `FILTERS`, the restore **silently does nothing**. The filter appears
active in the URL, the menu shows at its default, no error is thrown. This class of bug only
surfaces when someone manually tests a shared URL.

### 2. Dual registry maintenance — two sources of truth

Adding or modifying a filter requires updating in two places:

| File | What it holds |
|---|---|
| `config/filters.yml` | Server-side param permit list, histogram config, display metadata |
| `FILTERS` constant in `filter_controller.js` | DOM element IDs, control type, value maps for JS restore |

These must stay in sync manually. There is no compile-time or test-time check that they agree.

**Recent example:** adding `rate_tier` on branch `feat/variety-of-fixes-state-and-water-bill`
required updating both `config/filters.yml` (new filter entry) and the `FILTERS` constant
(new `rate_tier` type entry with button ID map). Every future filter addition carries this tax.

### 3. No automated test coverage for the restore path

There are no request specs asserting "GET / with `encoded=` renders filter menus in the correct
visual state." This is not an oversight — it is a **structural consequence** of where the
behavior lives.

Request specs test server-rendered HTML. `#restoreDomState` runs in `connect()` on the client
after the page loads. There is nothing for a request spec to assert — the server returns HTML
with all filter menus at their static defaults regardless of what `encoded=` contains. The
filter state only appears visually after JavaScript runs.

**Can we backfill these tests now, without the refactor?**

Not with request specs — the behavior being tested does not exist server-side yet. The only
option today would be Capybara system specs, which drive a real browser and can observe JS
behavior. But system specs are significantly slower, add infrastructure overhead, and would be
deleted when the refactor ships (because the request spec version would replace them). Writing
them now to discard them later is waste. The efficient path is: do the refactor, then write
fast request specs that survive long-term.

The test gap closes automatically when the refactor moves the behavior to the server:
`GET / with encoded=` → assert filter menu HTML → straightforward request spec.

---

## Why This Also Blocks Cleaner URL Sharing

Adding `view=table` to the URL (so shared links land on the correct map/table section) is
currently deferred because of this same split. See `docs/decisions/URL_MANAGEMENT.md`.

Today, initial page state is restored by `filter_controller#connect()` calling `#restoreFromUrl()`.
Adding `nav_controller#connect()` doing the same for `view=` introduces cross-controller
coordination: both fire at page load, both may trigger a table frame reload, creating a
potential double-request.

After the server-render refactor, `HomeController#index` decodes all URL state once and the
template renders the correct initial HTML — active section, filter menus, column panel. No
connect-time coordination needed. `view=table` becomes one more param the controller reads,
not a new JS restore path.

---

## How the Two Flows Work Today

### Apply (normal use)

```
User clicks Apply
  → #collectFilters (read DOM)
  → FilterState.set
  → encoded= blob in URL (#syncToUrl)
  → filters:changed → map + table Turbo frame reloads with encoded param
  → server decodes → apply_filters → correct rows
```

### Full page load / shared URL (today — JS path)

```
GET /?encoded=...
  → HomeController#index renders filter menus at static defaults (no params in ERB)
  → filter_controller#connect → #restoreFromUrl
  → decode blob → #restoreDomState (walks DOM by hardcoded IDs, per control type)
  → FilterState.set → reload table + stats frames
```

### Full page load / shared URL (target — server path)

```
GET /?encoded=...
  → HomeController#index decodes blob once → @filter_state, @column_state, @view_state
  → ERB renders filter menus with correct checked/unchecked/value state
  → ERB renders manage-columns panel (unchanged from today)
  → template renders correct active section (map/table)
  → filter_controller#connect → FilterState.set → reload table + stats frames
    (no #restoreDomState — menus already correct in HTML)
```

---

## Target Architecture

```
encoded= blob (filters + cols) + view= param
         ↓
HomeController#index (decodes once)
         ↓
         ├── @filter_state  → _filter_menus.html.erb   (server render — NEW)
         ├── @column_state  → _manage_columns_list.html.erb (server render — unchanged)
         ├── @view_state    → index.html.erb active section (server render — NEW)
         └── table/map/export: filter_params + ColumnRegistry (unchanged)
```

`filter_controller.js` keeps: `#collectFilters`, `#syncToUrl`, badge updates,
stats/table frame reloads, slider interaction. Loses: `#restoreDomState`.

---

## What Gets Deleted vs. What Stays

| | Today | After refactor |
|---|---|---|
| `#restoreDomState` | ~200 lines of DOM-walking restore logic | **Deleted** |
| `FILTERS` constant (restore entries) | ~40 control definitions with DOM IDs | Slimmed to interaction-only (~10–15 entries for sliders, autocomplete) |
| `#restoreFromUrl` | Decode → `#restoreDomState` → `FilterState.set` → frame reloads | Simplified: `FilterState.set` → frame reloads only |
| `HomeController#index` | No `@filter_state` passed to views | Decodes blob once, passes `@filter_state` |
| Filter menu ERB | Static defaults, no state awareness | Reads `@filter_state` for initial values |
| Request spec coverage | None for restore path | Full coverage: `GET / with encoded=` → assert HTML |

---

## Implementation Plan

### Phase 1 — Foundation (do this first, everything else builds on it)

- [ ] Add `HomeController#index` assignment: `@filter_state = decoded_state["filters"] || {}`
- [ ] Add view helper methods: `filter_checked?(param, value)`, `filter_active?(param)`,
      `filter_range_value(param, :min)`, `filter_range_value(param, :max)`
- [ ] Write request specs: `GET /` with `encoded=` → assert one radio, one checkbox,
      one range render correctly in HTML. These specs will fail until Phase 2 wires the ERB.
- [ ] **Do not proceed to Phase 2 until Phase 1 specs are written and failing correctly.**

### Phase 2 — Control types (incremental, one type at a time)

Work through each control type. Write/update the request spec first (red), wire the ERB (green).
Visual browser check after each type before moving to the next.

| Control type | Examples | Notes |
|---|---|---|
| Radio | Water source, boundary type | Simplest — one active value |
| Bool checkbox | Source water protection, open violations, wholesaler | Single param → checked state |
| Multi-select group | Owner type, primacy type | Array value → multiple checked |
| Rate tier buttons | Rate tier | Custom button group — check `rate_tier` type in FILTERS |
| Range inputs | Area, violation counts | Two params (min/max) → input values |
| Subcat panels | Health violations 5yr/10yr | Expand/collapse state + child ranges |
| Histogram sliders | Violation ranges, CVI, SVI | Server sets initial min/max as data attrs; JS still positions handles |
| Place autocomplete | Place geoid filter | Geoid (hidden) + display name (visible) — needs JS coordination for name display |

**Rate tier note:** this control type was added recently and already required dual-registry
updates. It's a good first candidate for the non-trivial types — it's new enough that the
code is fresh, and fixing it removes the most recently incurred debt.

### Phase 3 — Remove JS restore

- [ ] Delete `#restoreDomState` from `filter_controller.js`
- [ ] Remove restore-only entries from `FILTERS` constant — keep only entries needed for
      interaction (slider behavior, place autocomplete wiring, Apply/Reset)
- [ ] Simplify `#restoreFromUrl`: remove `#restoreDomState` call; keep `FilterState.set` and frame reloads
- [ ] Add `view=` URL param support (see `docs/decisions/URL_MANAGEMENT.md`):
      `HomeController#index` reads `params[:view]`, passes to template, template renders active section
- [ ] Update `docs/decisions/URL_MANAGEMENT.md` — remove "Deferred" note on `view=` row
- [ ] Delete this file. Reference the closing PR in the commit message.

---

## Manual QA Checklist

Run after Phase 2 (each control type) and again after Phase 3 (full pass).

For each test, construct a shared URL with that filter active (`encoded=` blob) and verify
both the visual menu state and the table/map data match.

- [ ] Radio filter restores (water source: groundwater vs. surface water)
- [ ] Bool checkboxes restore (source water protection, open violations, wholesaler, school/daycare)
- [ ] Multi-select groups restore (owner type, primacy type — multiple selected)
- [ ] Rate tier buttons restore (one or more active)
- [ ] Range inputs restore min/max values
- [ ] Subcat panel restores (correct child expanded, child ranges populated)
- [ ] Histogram slider handles land at correct positions
- [ ] Place filter restores display name (not just blank or geoid)
- [ ] Table data matches restored filter state
- [ ] Map data matches restored filter state
- [ ] Reset clears all menus correctly
- [ ] Apply after restore re-fires correctly (no double-load)
- [ ] Shared URL with no filters renders menus at defaults
- [ ] Shared URL with `view=table` lands on table section (Phase 3)

---

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Regression in shared URL restore | Request specs per control type (Phase 1 scaffolding) catch regressions before ship |
| Histogram sliders — handle positions can't be server-rendered | Hybrid: server sets `data-min`/`data-max` as attributes; JS reads them to position handles. Slider interaction JS stays unchanged. |
| Place autocomplete — display name needs JS | Server renders geoid into hidden field; JS autocomplete populates display name on connect if geoid present. One targeted `connect()` enhancement, not full restore logic. |
| Silent failure during Phase 2 incremental work | Each control type has a failing spec before ERB is wired — failures are loud, not silent |
| Turbo cache re-firing connect() after back navigation | After Phase 3, `#restoreFromUrl` only calls `FilterState.set` + frame reloads — idempotent. No DOM manipulation to mis-apply. |

---

## Related Docs

- `docs/decisions/URL_MANAGEMENT.md` — URL schema, blob structure, `view=` deferral explanation
- `docs/open_items/FILTER_SERVER_RENDER.md` — this file
- `config/filters.yml` — server-side filter registry
- `app/javascript/controllers/filter_controller.js` — `#restoreDomState`, `FILTERS` constant
- `app/filters/filter_registry.rb` — server-side param permit list

> **Cleanup:** Delete this file when filter menus are server-rendered from URL state and
> `#restoreDomState` is removed. Reference the closing PR in the commit message.
