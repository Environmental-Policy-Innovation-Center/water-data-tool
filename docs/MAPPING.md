# MAPPING.md — Map Layer Reference

Complete reference for the Mapbox GL JS map: layers, styles, interactions, and state changes.
The map is managed by `app/javascript/controllers/map_controller.js`.

> **Status key used in this document:**
> - No marker — current, working behavior as of today
> - **[M10 — not built]** — planned behavior, not yet implemented
> - **[Future — not in roadmap]** — legacy feature that has not been specced for V2

---

## Tile Source

All map data comes from a single vector tile source named `"wdt"`, served by `TilesController`:

```
GET /tiles/:z/:x/:y
```

The source contains four **source layers** (data channels baked into each tile):

| Source layer | Contains | Notes |
|---|---|---|
| `pws` | PWS service area polygons | Properties: `pwsid`, `pws_name`, `stusps`, `symbology_field`, `population_served_count`, `service_connections_count` |
| `places` | Census place boundaries | Properties: `geoid`, `name`, `place_pwsids` |
| `counties` | County boundaries | Properties: `geoid`, `name` |
| `states` | State boundaries | Properties: `geoid`, `stusps`, `name` |

---

## Tile Caching

Tiles are generated on-demand by PostGIS (`ST_AsMVT`) and cached in the `tile_cache` database table as binary blobs. The cache is **global and shared across all users** — the first user to request any tile pays the generation cost; every subsequent user gets the cached version instantly regardless of who originally generated it.

### Find-or-create per request

`TileGenerator.build_tile(z, x, y)` checks the cache for all 4 layers at once. Any layers already cached are returned immediately; missing layers are generated, persisted, and returned. A partially-cached tile coordinate (e.g. 3 of 4 layers present) only generates the missing layers.

### Cache lifecycle

1. **Cold** — tile has never been requested; PostGIS generates it from `service_area_geometries` (slow, especially at low zoom where many polygons are included)
2. **Warm** — tile exists in `tile_cache`; returned as a simple DB lookup (fast)
3. **Refreshing** — ETL identifies affected tile coordinates and `TileCacheRefreshJob` overwrites those cached rows in the background; old cached rows remain readable until replacements are ready

Normal imports refresh selectively. `epa_sabs.csv` reports PWS IDs when map-relevant attributes change, `epa_sabs_geoms.geojson` reports PWS IDs and previous geometry bounds when geometry digests change, and `TileImpact` converts those bounds into affected z5-z8 layer coordinates with a small edge margin.

The full `bust_tile_cache` + `TileCacheWarmJob` path remains available for explicit full-refresh fallbacks, such as broad cartographic boundary changes.

### Pre-warming (TileCacheWarmJob)

For full-refresh maintenance, `TileCacheWarmJob` pre-generates tiles for z0-z8 using US region bounding boxes (continental US, AK, HI, PR, Guam+CNMI). This skips empty ocean and land tiles entirely and covers through city/district zoom — the level where users first interact with individual water utility polygons. z9+ tiles generate on-demand (fast, small area).

The warm job takes ~32 minutes at national scale (~44k systems). See `scratch/performance_work.md` for full timing data.

### Selective refresh (TileImpact + TileCacheRefreshJob)

After normal imports, `TileImpact` calculates affected z5-z8 coordinates for changed PWS and place bounds. It adds a one-tile margin so edge-adjacent tiles are refreshed, deduplicates coordinates, and enqueues bounded `TileCacheRefreshJob` batches on the `tile_refresh` queue. Each refresh job calls `TileGenerator.generate_tile!` for the affected layer/z/x/y rows.

### Zoom level tile counts

Warming stops at z8 because z9+ on-demand generation is fast (each tile covers a small area with few polygons). The smart bounding-box approach uses far fewer coordinates than a blind full-grid warm:

| Zoom | US-only coords | Full grid | Reduction | × 4 layers |
|------|---------------|-----------|-----------|------------|
| z0 | 1 | 1 | 0% | 4 |
| z1 | 2 | 4 | 50% | 8 |
| z2 | 4 | 16 | 75% | 16 |
| z3 | 9 | 64 | 86% | 36 |
| z4 | 23 | 256 | 91% | 92 |
| z5 | 59 | 1,024 | 94% | 236 |
| z6 | 172 | 4,096 | 96% | 688 |
| z7 | 608 | 16,384 | 96% | 2,432 |
| z8 | 2,335 | 65,536 | 96% | 9,340 |
| **z0–z8 total** | **3,213** | **349,525** | **96.5%** | **~12,852 ops** |
| z9+ | — | millions | — | impractical to warm |

### Geometry simplification by zoom

Tile generation applies `ST_SimplifyPreserveTopology` with a tolerance that decreases as zoom increases — coarser at low zoom (national view), finer at high zoom (street level):

| Max zoom | Tolerance |
|----------|-----------|
| z≤4 | 0.05 |
| z5 | 0.01 |
| z6 | 0.005 |
| z7 | 0.001 |
| z8 | 0.0005 |
| z9 | 0.0001 |
| z10 | 0.00005 |
| z11 | 0.00001 |
| z12+ | 0 (no simplification — raw geometry) |

---

## Map Layers

`map_controller.js` adds 11 layers across two insertion modes:

- **`addLayer(layer, firstLineId)`** — inserts the layer *before* the first line layer in the base Mapbox style, placing it below roads and labels
- **`addLayer(layer)`** (no second argument) — appends to the top of the full layer stack, placing it above roads and labels

This creates a **roads-in-the-middle sandwich**: data fills and hover borders sit below roads (so road labels stay readable), while selection highlights and outlines sit above roads (so they're always visible regardless of base map content).

### All Layers — Render Order Summary

Listed bottom → top as actually rendered, not in code insertion order:

| # | Layer id | Type | Source layer | Purpose | Insertion |
|---|---|---|---|---|---|
| 1 | `states` | fill | `states` | Hit area for state hover/click; hover fill driven by feature-state | before `firstLineId` |
| 2 | `counties` | fill | `counties` | Transparent hit area for county hover/click | before `firstLineId` |
| 3 | `places` | fill (minzoom 8) | `places` | Transparent hit area for place hover/click | before `firstLineId` |
| 4 | `pws` | fill | `pws` | Main PWS polygon fill (green, 20% opacity) | before `firstLineId` |
| 5 | `pws_hover` | line | `pws` | Thicker black stroke on hovered PWS polygon | before `firstLineId` |
| 6 | `states_hover_outline` | line | `states` | Grey border outline while mousing over a state (feature-state driven) | before `firstLineId` |
| — | *(roads & labels from base style)* | — | — | — | — |
| 7 | `states_filter` | line | `states` | Black border outline after clicking a state | appended to top |
| 8 | `counties_filter` | line | `counties` | Green border on selected county *(not yet triggered)* | appended to top |
| 9 | `places_filter` | line | `places` | Green border on selected place *(not yet triggered)* | appended to top |
| 10 | `pws_outline` | line (minzoom 8) | `pws` | Thin black stroke at street-level zoom | appended to top |
| 11 | `selected_pws` | line | `pws` | Red stroke on clicked PWS polygon | appended to top |

**Why this order matters:** `pws_hover` and `states_hover_outline` (rows 5–6) sit below roads — road labels can overdraw them at low zoom, which is acceptable since hover is only meaningful at higher zoom. The hover fill on `states` (row 1) is driven by `feature-state` expressions baked into its paint properties rather than a separate layer, so it also sits below roads. Selection and filter highlights (rows 7–11) are above roads and always unobscured.

Detailed paint properties, visibility rules, and interaction triggers for each group are in the sections below.

### Geographic boundary fills (hit areas)

These layers are visually transparent. Their only purpose is to provide a click/hover target for state, county, and place geography.

| Layer id | Source layer | Type | Visible? | Paint |
|---|---|---|---|---|
| `states` | `states` | fill | Always | Hover: green fill (`rgb(78,163,36)`) 20% opacity via feature-state; default: transparent. `#eee` outline always. |
| `counties` | `counties` | fill | Always | Transparent fill, `#eee` outline |
| `places` | `places` | fill | minzoom 8 | Transparent fill, `#eee` outline |

---

### Geography highlight layers

These layers show visual feedback when the user hovers or clicks on a state, county, or place.

State hover is driven by `map.setFeatureState()` — on `mousemove`, the hovered state feature gets `{ hover: true }` written into its GPU-side state store (keyed by FIPS `geoid` via `promoteId`); on `mouseleave` (debounced 100ms) the state is cleared. This approach updates all tile fragments of the same state in a single render frame, avoiding the patchy fill that a `setFilter` approach produces.

The green fill on hover is a paint expression on the base `states` layer itself (`["case", HOVER_STATE_EXPR, ...]`). The `states_hover_outline` line layer shows a grey border using the same `HOVER_STATE_EXPR` — its `line-width` is 1 when hover is true, 0 otherwise (no separate filter needed).

`states_filter`, `counties_filter`, and `places_filter` are controlled by `map.setFilter()` — default filter `["in", "geoid", ""]` hides them entirely.

| Layer id | Source layer | Type | Color | Triggered by |
|---|---|---|---|---|
| `states` (hover paint) | `states` | fill | Green (`rgb(78,163,36)`), 20% opacity | Mouse over a state (`setFeatureState`) |
| `states_hover_outline` | `states` | line | Grey (`#999`), 1px | Mouse over a state (`setFeatureState`) |
| `states_filter` | `states` | line | Black, 2px | Click on a state (`setFilter`) |
| `counties_filter` | `counties` | line | Green (`rgb(78,163,36)`), 2px | *(reserved — not currently triggered by UI)* |
| `places_filter` | `places` | line | Green (`rgb(78,163,36)`), 2px | *(reserved — not currently triggered by UI)* |

**Note:** `counties_filter` and `places_filter` layers exist and are wired in the JS but are not currently triggered by any UI interaction. They are placeholders for when county/place boundary filtering is added.

---

### PWS service area layers

These layers render the actual drinking water system data.

| Layer id | Source layer | Type | Visible | Paint | Notes |
|---|---|---|---|---|---|
| `pws` | `pws` | fill | Always | Green fill (`rgb(78,163,36)`), 20% opacity, black outline | Main polygon fill. **[M10 — not built]** Will be filtered to matching pwsids when filters are active |
| `pws_outline` | `pws` | line | minzoom 8 | Black, 1.5–3.5px (zoom-interpolated) | Thin border at street-level zoom. **[M10 — not built]** Filtered same as `pws` |
| `pws_hover` | `pws` | line | On hover only | Black, 2–4.5px (zoom-interpolated) | Thicker border on the hovered system; controlled by `setFilter` |
| `selected_pws` | `pws` | line | On click only | Red (`#f00`), 2px | Highlights the clicked system; `visibility: none` until a system is clicked |

**Zoom logic:**
- Below zoom 8: polygon clicks trigger a `flyTo` to zoom 8.5 instead of opening a popup
- Above zoom 8: `pws_outline` appears; polygon clicks open popups

---

## Interaction Behaviors

### State hover / click

| Event | Layer | Result |
|---|---|---|
| `mousemove` on `states` | `states` | Cursor → pointer; `setFeatureState({ hover: true })` on that state's feature (green fill via `states_hover`) |
| `mouseleave` from `states` | `states` | Cursor reset; feature-state cleared (100ms debounced to prevent flicker at tile boundaries) |
| `click` on `states` | `states` | `states_hover` feature-state cleared; `states_filter` border set to that state's `geoid` via `setFilter` |

**State zoom-to-fit:** On click, `#fitToState` looks up the state's bounding box in the `STATE_FIT_BOUNDS` constant (PostGIS-derived, hardcoded in JS). A static lookup is used instead of an API call (50–150ms latency on every click) or `querySourceFeatures` (`querySourceFeatures` only returns geometry for tiles already in the browser viewport — unreliable for adjacent or off-screen states). State borders are legally fixed, so the data is stable. AK is omitted from the table because its bbox crosses the antimeridian; it falls back to `REGION_CAMERAS`.

**Note:** Clicking a state draws a border outline but does not apply a data filter. State-level data filtering is done through the Boundaries filter in the filter bar, not by clicking on the map.

---

### PWS polygon hover

Active only at zoom ≥ 5 (below that, systems are too small to distinguish).

| Event | Result |
|---|---|
| `mousemove` on `pws` | Cursor → pointer; `pws_hover` border appears on that system; hover popup shows system name, state, service connections, customers served |
| `mouseleave` from `pws` | Cursor reset; `pws_hover` cleared; hover popup removed |
| `zoomstart` | `pws_hover` cleared; hover popup removed |

**Hover popup content:**
- Utility Name
- System ID (pwsid)
- State
- Service connections
- Customers served

---

### PWS polygon click

| Zoom | Event | Result |
|---|---|---|
| < 8 | Click `pws` | `flyTo` center at click location, zoom 8.5 (zoom in to make polygon clickable) |
| ≥ 8 | Click `pws` | Hover popup removed; pinned click popup opened at click location |

**Click popup content:**
- Utility Name
- System ID (pwsid)
- State
- Type (symbology_field)
- Service connections
- Customers served
- "View Full Report" — link to `/public_water_systems/{pwsid}/report`

The click popup stays pinned (hover popup is suppressed for the pinned system). Clicking anywhere off a PWS polygon dismisses it. Clicking a different PWS replaces it.

**View Full Report (from click popup)**

The link opens the standalone report page (`layouts/report.html.erb`). The report page detects whether it was navigated to from the same app (via `request.referer` host check) and renders different controls accordingly:

| Context | Controls shown |
|---|---|
| Navigated from the app (map popup click) | Print + close (X) button — clicking X calls `history.back()` to return to the map |
| Direct URL / new tab / copy-paste | Print + back-to-map icon link (`link_to root_path`) |

---

### Geocoder (map search)

The geocoder is rendered into the filter bar (`#geocoder-li`) rather than as a floating map control. When a result is selected, the map flies to it at a zoom level determined by place type:

| Place type | Zoom |
|---|---|
| Region (state) | 5 |
| District | 7 |
| Place (city/town) | 8 |
| Everything else (address, POI) | 10 |

---

## Initial Viewport

On page load and when the user clicks **48**, `map_controller.js` calls `#fitDefaultView`. Layout is inferred from whether `#container-sidebar` is visible (`hidden sm:flex` → zero width on phones) — no `matchMedia` branches.

| Layout | Signal | Camera | `minZoom` |
|---|---|---|---|
| Desktop | Sidebar `width > 0` | `fitBounds` on continental US (`[-125.5, 23.5]` → `[-65.5, 49.5]`) with left padding for the floating sidebar | 3 |
| Mobile | Sidebar hidden | `center: [-97.6, 38.5]`, `zoom: 2` | 2 |

Left padding on desktop matches `sidebar_controller.js` (`sidebar right edge + 16px CONTROLS_GAP + 20px margin`). Mobile uses center/zoom instead of `fitBounds` because portrait aspect ratio plus full-edge padding produced poor framing.

**Desktop-only map chrome** (hidden below `sm` / 640px):
- Mapbox zoom +/− (`.mapboxgl-ctrl-group` in `application.css`)
- Region shortcuts (`#container-region-nav` — 48 / AK / HI / PR / GU / MP)

Tuning constants live at the top of `map_controller.js` (`MOBILE_DEFAULT_ZOOM`, `DESKTOP_US_BOUNDS`, etc.). `MOBILE_MIN_ZOOM` must be ≤ `MOBILE_DEFAULT_ZOOM` or Mapbox clamps the requested zoom.

---

## Programmatic Zoom Methods

These are called by nav/button elements outside the map canvas:

| Method | Behavior |
|---|---|
| `zoom48()` | Clears geocoder input; calls `#fitDefaultView` (same framing as initial load) |
| `zoomAk()` | Flies to Alaska (`-149.504, 61.342`, zoom ~5) |
| `zoomHi()` | Flies to Hawaii (`-157.0, 20.5`, zoom ~5) |
| `zoomPr()` | Flies to Puerto Rico (`-66.590, 18.220`, zoom 8) |
| `zoomGu()` | Flies to Guam (`144.794, 13.444`, zoom 10) |
| `zoomMp()` | Flies to Northern Mariana Islands (`145.674, 15.180`, zoom 9) |

---

## Layer State Summary

| Layer | Default state | Changes when |
|---|---|---|
| `states` | Visible (transparent) | Never |
| `counties` | Visible (transparent) | Never |
| `places` | Visible at zoom ≥ 8 (transparent) | Zoom |
| `states_hover_outline` | Hidden (line-width 0, no feature-state set) | Mouse enters/leaves a state |
| `states_filter` | Hidden (empty filter) | User clicks a state |
| `counties_filter` | Hidden (empty filter) | *(not currently triggered)* |
| `places_filter` | Hidden (empty filter) | *(not currently triggered)* |
| `pws` | All systems visible | **[M10 — not built]** filtered to matching pwsids on filter change |
| `pws_hover` | Hidden (empty filter) | Mouse enters/leaves a PWS polygon (zoom ≥ 5) |
| `pws_outline` | Visible at zoom ≥ 8 | Zoom; **[M10 — not built]** filtered same as `pws` |
| `selected_pws` | Hidden (`visibility: none`) | System clicked (shown); popup closed (hidden) |

---

## Dev Console (localhost only)

`mapDebug` is assigned to the Mapbox GL map instance when running on `localhost` (see `map_controller.js`). It is `undefined` in production.

### Useful commands

| Command | What it returns |
|---|---|
| `mapDebug.getZoom()` | Current zoom level (once) |
| `mapDebug.getCenter()` | Current map center `{lng, lat}` (once) |
| `mapDebug.getStyle().layers` | Array of all active Mapbox GL layers and their current state |
| `mapDebug.queryRenderedFeatures()` | All features visible in the current viewport |

### Continuous tracking

Register a listener to log on every zoom change:

```js
mapDebug.on('zoom', () => console.log(mapDebug.getZoom()))
```

Same pattern works for any map event (`move`, `moveend`, `click`, etc.):

```js
mapDebug.on('move', () => console.log(mapDebug.getCenter()))
```

These listeners persist for the browser session. Reload the page to clear them.

---

## What M10 Will Change

M10 adds filter→map sync. After M10, when the user applies filters:

- `pws` and `pws_outline` will each have a Mapbox GL filter expression applied: `["in", "pwsid", ...matchingIds]`
- Non-matching systems disappear from the map
- When all filters are cleared: filter expressions reset to `null` (show all)
- On page load with filter params in the URL: filter is applied immediately after tiles load

See `scratch/roadmap_m10/m10_guide.md` for implementation details.

---

## [Future — not in roadmap]: Choropleth Layer

The legacy app had a "Continuous display" checkbox under each demographic histogram slider. Checking it color-coded all visible PWS polygons in 8 quantile buckets by that variable (e.g. median household income, poverty rate). This used `map.setPaintProperty("pws", "fill-color", fillExpression)` with a case expression mapping pwsid ranges to colors.

This feature is not in the current roadmap. It depends on the demographic histogram sliders being built first (the largest remaining filter UI gap — see `docs/TODO.md`). When it is built, it will modify the paint property of the existing `pws` layer rather than adding a new layer.

---

## TODO

### 1. Fix overlapping-layer click bug

**Problem:** `map.on("click", "pws", ...)` and `map.on("click", "states", ...)` are registered as independent handlers. Mapbox GL JS does not stop propagation between layer-scoped handlers, so a click on a PWS polygon at zoom ≥ 8 fires **both** simultaneously — the PWS popup opens and the state border highlight (`states_filter`) is set. This is unintentional.

**Fix:** Replace all layer-scoped click handlers with a single `map.on("click", ...)` handler that uses `queryRenderedFeatures` to check layers in explicit priority order and returns early after the first match:

```js
map.on("click", (e) => {
  const pws = map.queryRenderedFeatures(e.point, { layers: ["pws"] })
  if (pws.length > 0) { /* handle PWS — return */ return }

  const counties = map.queryRenderedFeatures(e.point, { layers: ["counties"] })
  if (counties.length > 0) { /* handle county — return */ return }

  const states = map.queryRenderedFeatures(e.point, { layers: ["states"] })
  if (states.length > 0) { /* handle state */ }
})
```

Priority order: `pws` > `counties` > `places` > `states`. This is the conventional Mapbox GL JS pattern for overlapping interactive layers.

---

### 2. Wire up `counties_filter` and `places_filter`

**Problem:** Both layers exist and are styled but are never triggered by any UI interaction. In the legacy app, clicking a county or place boundary was the primary geographic filter mechanism — it highlighted the border and narrowed the visible PWS polygons to systems within that geography.

**What the legacy app did:**
- County/place features had pre-baked `county_pwsids`/`place_pwsids` JSON arrays embedded directly in tile properties. Clicking a boundary extracted that list and passed it to `updateFilter()`.
- `counties_hover` and `places_hover` fill layers (analogous to `states_hover`) also existed in the legacy app but were not ported to V2.

**What V2 needs:**
1. `mousemove`/`mouseleave` handlers on `counties` and `places` to drive hover highlights. This requires adding `counties_hover` and `places_hover` fill layers (same pattern as `states_hover`) — these layers were dropped during the port and need to be added back.
2. Click handlers on `counties` and `places` that set `counties_filter`/`places_filter` and trigger a `/map?...` server fetch (the V2 filter approach), rather than relying on pre-baked tile properties.
3. Geocoder integration: when a geocoder result has `place_type` of `district` or `place`, set the corresponding filter layer (legacy already did this via `queryRenderedFeatures` after flying to the result).
4. Zoom gates: legacy used zoom 6–10 for county hover/click and zoom ≥ 10 for place hover/click — reasonable starting point for V2.

**Note:** These click handlers should be implemented inside the consolidated single-handler described in TODO #1, not as additional layer-scoped handlers.

---

## Glossary

**Centroid**
The geometric center point of a polygon. Stored in `service_area_geometries.centroid` and used internally (e.g. bounding box filtering in the warm job). Not rendered on the map.

**Choropleth**
A map where areas are shaded or colored according to a data variable (e.g. median household income). The legacy app supported this via a "Continuous display" toggle on demographic sliders. Not yet built in V2.

**Fill layer**
A Mapbox GL layer type that renders solid or semi-transparent color inside a polygon boundary. Used for service area polygons (`pws`) and transparent hit areas (`states`, `counties`, `places`).

**Filter expression**
A Mapbox GL JS instruction that controls which features in a source layer are rendered by a given map layer. Example: `["in", "pwsid", "OH001", "OH002"]` renders only those two systems. Setting the filter to `null` removes it and shows all features.

**flyTo**
A Mapbox GL JS method that smoothly animates the map camera to a new center and/or zoom level. Used when clicking a centroid dot or a polygon at low zoom to bring the user to a closer view.

**Geocoder**
A search control that converts a place name or address into map coordinates. This app uses the Mapbox Geocoder plugin, rendered into the filter bar rather than floating on the map canvas.

**Hit area**
A transparent layer whose only purpose is to receive mouse events (hover, click). The `states`, `counties`, and `places` fill layers are hit areas — they have no visible color but register interactions over their geographic boundaries.

**Line layer**
A Mapbox GL layer type that renders a stroke along the edge of a polygon or along a path. Used for borders, outlines, and highlights (`pws_outline`, `pws_hover`, `states_filter`, etc.).

**Mapbox GL JS**
The JavaScript library used to render the interactive map. It draws map tiles using WebGL and exposes an API for adding layers, handling events, and applying filters/styles dynamically.

**minzoom / maxzoom**
Per-layer zoom thresholds. A layer with `minzoom: 8` is invisible below zoom level 8. A layer with `maxzoom: 8` is invisible at zoom level 8 and above. Used here for `pws_outline` (minzoom 8) and `places` (minzoom 8).

**MVT (Mapbox Vector Tile)**
A binary tile format (protobuf) used to deliver geographic data to the browser in chunks. The server generates tiles on-demand using PostGIS's `ST_AsMVT` function and caches them in the `tile_cache` table. The browser reassembles them into a continuous map.

**Paint property**
The visual styling attributes of a Mapbox GL layer — color, opacity, line width, etc. Can be set statically or driven by data expressions. The choropleth feature works by dynamically changing the `fill-color` paint property on the `pws` layer.

**Popup**
A small info card that appears on the map anchored to a geographic location. This app has two popup types: a hover popup (appears when mousing over a PWS polygon) and a click popup (appears when clicking a polygon, includes the "View Full Report" link).

**PWS (Public Water System)**
A drinking water utility serving the public. The central data entity in this app. Each PWS has a unique `pwsid` string identifier (e.g. `"VT0000101"`), a service area polygon, and associated compliance, demographic, and funding data.

**Service area**
The geographic boundary of a PWS — the area it is licensed to serve. Stored as a PostGIS polygon in the `service_area_geometries` table and served via the `pws` source layer in vector tiles.

**Source layer**
A named data channel within a vector tile. A single tile request (`/tiles/z/x/y`) returns one binary blob containing multiple source layers (`pws`, `places`, `counties`, `states`). Mapbox GL map layers each read from one source layer.

**Vector tile**
See MVT. A tile that contains geographic feature data (points, lines, polygons) and their properties, as opposed to a raster tile which contains pre-rendered pixel imagery.

**Zoom level**
An integer (roughly 0–22) representing how far the map is zoomed in. Zoom 0 shows the whole world; zoom 22 shows individual buildings. Key thresholds in this app: zoom 3 (minimum zoom — restricted to North America view), zoom 5 (PWS hover activates), zoom 8 (polygon clicks open popups; `pws_outline` appears).
