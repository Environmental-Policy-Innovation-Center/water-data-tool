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

The source contains five **source layers** (data channels baked into each tile):

| Source layer | Contains | Notes |
|---|---|---|
| `pws` | PWS service area polygons | Properties: `pwsid`, `pws_name`, `stusps`, `symbology_field`, `population_served_count`, `service_connections_count` |
| `pws_points` | PWS centroid points | Same properties as `pws`; ensures systems are visible at low zoom before polygons are large enough to click |
| `places` | Census place boundaries | Properties: `geoid`, `name` |
| `counties` | County boundaries | Properties: `geoid`, `name` |
| `states` | State boundaries | Properties: `geoid`, `stusps` |

Tiles are generated on-demand by PostGIS (`ST_AsMVT`) and cached in the `tile_cache` table. See `docs/ETL.md` and `ARCHITECTURE.md` for tile caching and invalidation.

---

## Map Layers

Layers are added in this order (bottom → top). Layers added earlier appear below layers added later. Some layers are inserted before the first line layer in the base Mapbox style (`firstLineId`) so road and label layers stay on top.

### Geographic boundary fills (hit areas)

These layers are visually transparent. Their only purpose is to provide a click/hover target for state, county, and place geography.

| Layer id | Source layer | Type | Visible? | Paint |
|---|---|---|---|---|
| `states` | `states` | fill | Always | Transparent fill, `#eee` outline |
| `counties` | `counties` | fill | Always | Transparent fill, `#eee` outline |
| `places` | `places` | fill | minzoom 8 | Transparent fill, `#eee` outline |

---

### Geography highlight layers

These layers show visual feedback when the user hovers or clicks on a state, county, or place. They are controlled by `map.setFilter()` — default filter `["in", "geoid", ""]` hides them entirely.

| Layer id | Source layer | Type | Color | Triggered by |
|---|---|---|---|---|
| `states_hover` | `states` | fill | Green (`rgb(78,163,36)`), 20% opacity | Mouse over a state |
| `states_filter` | `states` | line | Black, 2px | Click on a state |
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
| `pws_points` | `pws_points` | circle | maxzoom 8 | Green circle, radius 2–5px by zoom, black 1px stroke, 70% opacity | Centroid dots shown at national/state zoom before polygons are visible. **[M10 — not built]** Filtered same as `pws` |
| `selected_pws` | `pws` | line | On click only | Red (`#f00`), 2px | Highlights the clicked system; `visibility: none` until a system is clicked |

**Zoom logic:**
- Below zoom 8: `pws_points` circles are shown; polygons render but are tiny
- Above zoom 8: `pws_outline` appears; `pws_points` are hidden
- Clicking a polygon below zoom 8 triggers a `flyTo` to zoom 8.5 instead of opening a popup

---

## Interaction Behaviors

### State hover / click

| Event | Layer | Result |
|---|---|---|
| `mousemove` on `states` | `states` | Cursor → pointer; `states_hover` filter set to that state's `geoid` (green fill) |
| `mouseleave` from `states` | `states` | Cursor reset; `states_hover` filter cleared |
| `click` on `states` | `states` | `states_hover` cleared; `states_filter` border set to that state's `geoid` |

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
| ≥ 8 | Click `pws` | Hover popup removed; `selected_pws` (red border) shown on that system; click popup opened |

**Click popup content:**
- Utility Name
- System ID (pwsid)
- State
- Type (symbology_field)
- Service connections
- Customers served
- "View Full Report" link → loads report in Turbo Frame overlay (`#report-body`), opens `#container-report`

When the click popup is closed: `selected_pws` layer hidden, popup reference cleared.

---

### PWS point click (low zoom)

| Event | Result |
|---|---|
| Click `pws_points` | `flyTo` center at click location, zoom 8.5 |
| Hover `pws_points` | Cursor → pointer |

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

## Programmatic Zoom Methods

These are called by nav/button elements outside the map canvas:

| Method | Behavior |
|---|---|
| `zoom48()` | Clears geocoder input; flies to continental US center (`-97.6, 40.27`, zoom 3.5) |
| `zoomAk()` | Flies to Alaska (`-149.504, 61.342`, zoom ~5) |
| `zoomHi()` | Flies to Hawaii (`-157.856, 21.305`, zoom ~6) |

---

## Layer State Summary

| Layer | Default state | Changes when |
|---|---|---|
| `states` | Visible (transparent) | Never |
| `counties` | Visible (transparent) | Never |
| `places` | Visible at zoom ≥ 8 (transparent) | Zoom |
| `states_hover` | Hidden (empty filter) | Mouse enters/leaves a state |
| `states_filter` | Hidden (empty filter) | User clicks a state |
| `counties_filter` | Hidden (empty filter) | *(not currently triggered)* |
| `places_filter` | Hidden (empty filter) | *(not currently triggered)* |
| `pws` | All systems visible | **[M10 — not built]** filtered to matching pwsids on filter change |
| `pws_hover` | Hidden (empty filter) | Mouse enters/leaves a PWS polygon (zoom ≥ 5) |
| `pws_outline` | Visible at zoom ≥ 8 | Zoom; **[M10 — not built]** filtered same as `pws` |
| `pws_points` | Visible at zoom < 8 | Zoom; **[M10 — not built]** filtered same as `pws` |
| `selected_pws` | Hidden (`visibility: none`) | System clicked (shown); popup closed (hidden) |

---

## What M10 Will Change

M10 adds filter→map sync. After M10, when the user applies filters:

- `pws`, `pws_outline`, and `pws_points` will each have a Mapbox GL filter expression applied: `["in", "pwsid", ...matchingIds]`
- Non-matching systems disappear from the map
- When all filters are cleared: filter expressions reset to `null` (show all)
- On page load with filter params in the URL: filter is applied immediately after tiles load

See `scratch/roadmap_m10/m10_guide.md` for implementation details.

---

## [Future — not in roadmap]: Choropleth Layer

The legacy app had a "Continuous display" checkbox under each demographic histogram slider. Checking it color-coded all visible PWS polygons in 8 quantile buckets by that variable (e.g. median household income, poverty rate). This used `map.setPaintProperty("pws", "fill-color", fillExpression)` with a case expression mapping pwsid ranges to colors.

This feature is not in the current roadmap. It depends on the demographic histogram sliders being built first (the largest remaining filter UI gap — see `docs/TODO.md`). When it is built, it will modify the paint property of the existing `pws` layer rather than adding a new layer.

---

## Glossary

**Centroid**
The geometric center point of a polygon. Used here as a fallback representation for PWS service areas at low zoom levels — when a polygon is too small to see or click, a centroid dot (`pws_points`) is shown instead.

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
Per-layer zoom thresholds. A layer with `minzoom: 8` is invisible below zoom level 8. A layer with `maxzoom: 8` is invisible at zoom level 8 and above. Used here to swap between centroid dots (`pws_points`, maxzoom 8) and polygon outlines (`pws_outline`, minzoom 8).

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
A named data channel within a vector tile. A single tile request (`/tiles/z/x/y`) returns one binary blob containing multiple source layers (`pws`, `pws_points`, `states`, etc.). Mapbox GL map layers each read from one source layer.

**Vector tile**
See MVT. A tile that contains geographic feature data (points, lines, polygons) and their properties, as opposed to a raster tile which contains pre-rendered pixel imagery.

**Zoom level**
An integer (roughly 0–22) representing how far the map is zoomed in. Zoom 0 shows the whole world; zoom 22 shows individual buildings. Key thresholds in this app: zoom 5 (PWS hover activates), zoom 8 (polygon clicks open popups; `pws_outline` appears; `pws_points` disappear).
