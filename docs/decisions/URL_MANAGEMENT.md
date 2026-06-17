# URL State Management

## The Problem

User state — filters and column visibility — is encoded in the URL. This is intentional: it makes views bookmarkable and shareable, a core use case. Sort and direction are also persisted in the URL (as explicit params), but page number and search are not — both are ephemeral and reset on every table reload.

Two pressure points exist as the app grows:

- **Filter params** — verbose keys like `synthetic_organic_chemicals_10yr_min` (36 chars each). With 128 possible filter params at worst case, filter state alone exceeds 3,000 chars unencoded.
- **Column state** — the `cols=` comma-separated param at full selection adds ~600 chars unencoded.

Worst-case total (all filters active, all columns visible, sort): **~4,445 chars**. The commonly cited "2,000-char URL limit" is a myth from IE6 — modern browsers handle 65,000+ chars. The real constraint is the web server: Nginx defaults to 8KB (8,192 chars), which the verbose worst-case approaches but doesn't hit. However, encoded worst-case is 1,540 chars — leaving 6,650+ chars of headroom regardless of future filter growth.

A third related problem: **selected-row exports** previously passed individual PWSID query params via GET, which hits URL limits around 150–200 selected rows. This is now resolved — exports use POST with a hybrid inclusion/exclusion model. See `docs/EXPORTS.md`.

---

## URL Schema

### Param structure

```
/?encoded=<blob>&sort=<col>&direction=<asc|desc>
```

| Param | What it holds | Notes |
|---|---|---|
| `encoded` | Zlib+Base64 blob: `{ filters: {...}, cols: "..." }` | Omitted entirely when no filters are active AND columns are at default |
| `sort` | Sort column key, e.g. `stusps` | Always explicit — never inside the blob |
| `direction` | `asc` or `desc` | Always explicit — never inside the blob |
| `page` | **Not in the URL** | Ephemeral — always resets to page 1 on any table reload |
| `search` | **Not in the URL** | Ephemeral — stored in `#table-query-state` DOM span for export only |
| `view` | **Not yet in the URL** | Active section (map/table/etc.) driven by `nav_controller.js#show()` on click — on page load, nothing calls `show()`, so the URL param would be ignored without additional connect-time logic to read it and apply the DOM state |

### Blob structure

The blob is a Zlib-compressed, URL-safe Base64-encoded JSON object. It holds two keys:

```json
{
  "filters": {                        // omitted when no filters active
    "gw_sw_code": "GW",               // radio filter — single value
    "owner_type": ["Local", "Federal"] // multi-select filter — array
  },
  "cols": "counties,stusps,-pwsid,-grant_eligible"
  //        ^^^^^^^^  ^^^^^^   ^^^^^^   ^^^^^^^^^^^^^
  //        visible   visible  hidden   hidden
  //
  // Full panel sequence in display order (set by Manage Columns drag-and-drop).
  // Plain key  → column is visible in the table.
  // -key       → column is hidden; position preserved for when it's re-enabled.
  // Omitted entirely when all columns are visible AND in the default YAML order.
}
```

**When `cols` is omitted:** all selectable columns are visible in the default order defined in `config/columns.yml`. The server renders the table and panel as if no column state exists.

**When `cols` is present:** the server parses it via `ColumnRegistry.parse_column_state` into two derived lists — visible column keys (drives table headers) and panel col keys (drives Manage Columns panel order and checkbox state). See `app/columns/column_registry.rb`.

**Column order and the `-` prefix** come from the Manage Columns panel. Dragging columns reorders the list; unchecking a column adds the `-` prefix. Clicking "Show Columns" writes the full panel sequence into the blob. "Reset" removes `cols` from the blob entirely (restoring YAML default order, all visible).

`filters` is omitted when no filters are active. When both `filters` and `cols` are omitted, `encoded=` is dropped entirely — the URL returns to bare `/`.

### When params are added / cleared

**`encoded`**

| Event | Result |
|---|---|
| Filter applied | Rebuilt from scratch: set if filters exist OR cols are non-default |
| Columns hidden/shown (Show Columns) | Existing blob decoded, `cols` key updated in place with full panel sequence (plain keys for visible, `-key` for hidden), re-encoded |
| Columns drag-reordered (Show Columns) | Same as above — drag order is reflected in the `cols` key sequence |
| Reset All filters | Rebuilt with empty FilterState — dropped if cols also at default |
| Column picker Reset (all cols, YAML order) | `cols` removed from blob; if no filters remain, `encoded=` dropped |

**`sort` + `direction`**

| Event | Result |
|---|---|
| Sort column header clicked → frame loads | `#onTableFrameLoad` reads `#table-query-state`; sets or updates params |
| Third click on sorted column → frame loads | `#table-query-state` has empty sort; params deleted from URL |
| Reset All filters | Sort params **unchanged** — sort is independent of filter state |
| Column picker Reset | Sort params **unchanged** — sort is independent of column visibility |
| Filter applied | `#syncToUrl()` reads existing sort and re-sets it — sort preserved |
| Column visibility changed | `#updateUrl()` only touches `encoded`; sort params untouched |

---

## Expected Behavior

### URL role: shareability, not live control

The URL is **trailing state, not a driver**. During active use, the flow is always: user action → JS updates internal state → `Turbo.visit` fires → URL updated after. The URL never triggers filtering or column changes mid-session.

The one exception is **initial page load from a shared URL**: `filter_controller.js#restoreFromUrl()` reads `encoded=` on `connect()`, restores **filter menu** DOM state via JS (`#restoreDomState`), and fires the initial table and stats frame requests. After that first load, the URL reverts to being a passive record of current state.

**Filters vs columns on reload:** Filter menus are JS-hydrated; the manage-columns panel should be server-rendered from the same blob (idiomatic Hotwire). Data for both is always applied server-side. See `docs/open_items/FILTER_SERVER_RENDER.md` for why the split exists and the long-term refactor plan.

### Sort

- **3-state cycle** — unsorted → `asc` → `desc` → unsorted. Third click removes `sort=` and `direction=` from URL entirely, restoring default `pws_name ASC` order with no sort indicator.
- **Sort persists through all resets** — resetting filters (individual menu or Reset All) and resetting column visibility both leave sort params unchanged. Sort is an independent user preference orthogonal to filter and column state.
- **Only one way to clear sort** — cycle back to unsorted via the column header (third click).
- **New column always starts at `asc`** — clicking a different column always starts at ascending, regardless of the previous column's direction.
- **Sort syncs after frame load, not before** — `filter_controller.js` listens for `turbo:frame-load` and reads `data-sort`/`data-direction` from the server-rendered `#table-query-state` span. The page URL reflects confirmed server state rather than a predicted fetch URL, preventing sync issues when navigations race or are cancelled.

### Page

- **Page is never shared** — page number is excluded from the URL entirely. Any table reload (filter apply, filter reset, column change) returns to page 1. Sharing a specific page number would confuse recipients whose result set differs.

### Column picker

- **No request when nothing changed** — clicking "Show Columns" or "Reset" with no actual column change fires no network request. The panel closes; nothing else happens.

### Prefetch

- **Hover does not prefetch** — Turbo 8 prefetches links on hover by default. `data-turbo-prefetch="false"` on the `data-table` frame suppresses this. Sort header links do not generate background requests on hover.

---

## Decisions

### 1. Filter + Column State → Zlib + Base64 GET param

Compress the entire filter and column state into a single opaque `encoded=` param:

```
/?encoded=eJyLjgUAAYAB_w
```

**Why Zlib+Base64 over string aliasing:**

Aliasing was evaluated. It reduces worst-case URL length to ~1,687 chars — under the limit — but only if the min/max direction is encoded into the alias itself (e.g., `a61n`/`a61x`). Aliases with `_min`/`_max` suffixes still exceed the limit. The result is an alias like `a61n` — completely unreadable, requiring a permanent alias registry to maintain. There is no readability payoff.

Zlib+Base64 is strictly better in this situation:
- No alias registry to maintain — new filters and columns just work
- Automatically handles future growth
- Same opaqueness as aliases
- Simpler implementation: one encode/decode utility vs. a registry mapping every param

Worst-case compression estimate: filter param names contain heavy repetition (`_rate_min=`, `_5yr_max=`, `_10yr_max=`). Deflate is designed for exactly this. Compressed + base64 encoded worst case lands well under 2,000 chars in typical use. The absolute worst case (all 110 range params simultaneously active) is a theoretical edge case that does not occur in real sessions.

**Human readability:** Not required. Shareable links are important; readable links are not.

### 2. Selected-Row Exports → POST

When specific rows are selected for export, IDs are submitted via POST body rather than GET query params. Uses a hybrid inclusion/exclusion model — see `docs/EXPORTS.md` for full design.

**Why POST:**
- POST bodies have no practical size limit — thousands of IDs are fine
- An export is an ephemeral one-time action, not a shareable URL — the core objection to POST (breaking bookmarking) does not apply here

**Why not switch back to GET now that Zlib+Base64 compression exists:**
The `encoded=` compression works well for filter state because filter param *names* contain heavy repeated substrings (`_min`, `_max`, `_5yr_`, `_10yr_`, `synthetic_organic_chemicals_`). Deflate is designed for exactly this repetition and compresses them dramatically. PWSID values (e.g. `TX0000123`, `CA0100003`) are essentially random — they share no repeated structure. Zlib gets much less leverage on them, and a list of 500–600 IDs would still produce a large encoded blob. POST eliminates the size constraint entirely with no tradeoff at any scale, and is the semantically correct verb for an ephemeral action.

**Filter-based exports** (all rows selected, no explicit IDs) also use POST for consistency — all three selection paths go through the same `create` action.

### 3. Verbose Filter Parameter Keys → Keep As-Is

Filter param names like `synthetic_organic_chemicals_10yr_min` are intentionally kept verbose and human-readable. Zlib compression actually benefits from long, repetitive key names — the more shared prefixes and suffixes across keys, the better deflate compresses them. Switching to short aliases (e.g. `a61n`) would require maintaining a permanent alias registry, produce no meaningful reduction in the compressed output, and eliminate all readability from uncompressed param lists. Verbose keys are kept; compression handles the URL length problem.

### 4. Sort + Direction → Explicit URL params, not in blob

`sort` and `direction` live as explicit URL params (`?sort=x&direction=y`) rather than inside the encoded blob. The `data-table` Turbo Frame navigates directly to sort link hrefs (built by `TableHeaderComponent#next_sort_url` from `request.query_parameters`); intercepting those clicks to encode sort into the blob would require restructuring how the server builds sort links. Keeping them explicit means no server changes and clean separation: the blob is filter + column state; sort is its own concern.

---

## What Was Considered and Rejected

| Approach | Why Rejected |
|---|---|
| String aliasing | Aliases are unreadable; requires registry maintenance; min/max direction must be encoded into alias (no `_min`/`_max` suffix); narrow worst-case buffer |
| Zlib+Base64 for ID exports | Worst-case borderline; POST is simpler and has no constraint |
| Server-side token storage | Introduces DB/Redis storage, TTL logic, expiration handling — operational overhead with no benefit over stateless compression |
| POST for filter state | Breaks bookmarking and link sharing, which are core use cases |
| Index mapping / bitmasking | Fragile to schema changes; breaks existing bookmarked URLs when columns added/removed |
| Sort/direction inside the blob | Requires intercepting sort link clicks in JS and restructuring `TableHeaderComponent`; explicit params are simpler and already flow through `request.query_parameters` correctly |

---

## Pattern Comparison

Approaches evaluated before choosing Zlib+Base64:

| Solution | URL Size | Resiliency to Future Changes | Custom Ordering Support | Maintenance Overhead |
|---|---|---|---|---|
| String Aliasing | Medium-Small | High (explicit alias per field) | High | Low (alias registry) |
| Encoding / Decoding | Medium | High (no coupling to code order) | High | None |
| Index Mapping | Tiny | Low (index shifts break old links) | High | Medium |
| Mixed Pattern | Small | Medium (inherits index fragility) | High | Medium |
| Bitmasking | Absolute Smallest | Low (bit removal breaks sequence) | No | High |
