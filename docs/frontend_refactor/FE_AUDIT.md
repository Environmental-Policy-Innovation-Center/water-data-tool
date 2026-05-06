# Frontend Architecture Audit

> Generated: 2026-04-27  
> Branch: `spike/fe-architecture-revamp`  
> Purpose: Inform a decision about frontend refactoring (Hotwire vs React SPA)

---

## 1. Stimulus Controllers

### Inventory

| File | Lines | Purpose |
|---|---|---|
| `map_controller.js` | 540 | Mapbox GL JS map, layers, hover/click, filter integration |
| `filter_controller.js` | 466 | Filter dropdown menus, filter state, responsive layout |
| `table_controller.js` | 168 | DataTables initialization, stats-bar frame reload |
| `datasets_controller.js` | 96 | Datasets catalog filter/sort |
| `place_autocomplete_controller.js` | 80 | Typeahead search for census places |
| `nav_controller.js` | 65 | Section switching (map/table/datasets/downloads), mobile menu |
| `report_controller.js` | 31 | Report overlay show/close, populates header from Turbo Frame |
| `export_controller.js` | 14 | CSV/GeoJSON download trigger |
| `slider_controller.js` | 8 | **Stub only — not implemented** |

Supporting module (not a controller):

| File | Lines | Purpose |
|---|---|---|
| `filter_state.js` | 35 | In-memory filter params singleton shared across controllers |

### Controller Registration

`controllers/index.js` uses `eagerLoadControllersFrom("controllers", application)` — all controllers in the `controllers/` directory are auto-registered. No manual registration needed. This is correct and conventional.

`controllers/application.js` creates the Stimulus application and sets `application.debug = false`. Correct.

### Per-Controller Detail

#### `map_controller.js` (540 lines)

**What it does:** Owns the Mapbox GL JS map instance. On `connect()`, creates `new window.mapboxgl.Map(...)` and stores it as `this.map`. On `load`, adds 12 vector tile layers (states, counties, places, PWS polygons, hover/filter highlight layers), binds all map events (hover, click, zoom), attaches the geocoder, and sets up zoom shortcut methods.

**Events listened to:** `filters:changed` (document-level custom event).  
**Events dispatched:** None.  
**External dependencies:** `window.mapboxgl` (Mapbox GL JS v3.14.0, loaded via CDN `<script>` tag), `window.MapboxGeocoder` (geocoder plugin v5.1.0, CDN), `filter_state.js` module.

**How filter → map works:** When `filters:changed` fires, `#onFiltersChanged()` fetches `/map?<params>` (returns `{ pwsids: [...] }`), then calls `this.map.setFilter("pws", ["in", "pwsid", ...pwsids])` — a direct Mapbox GL JS API call. No HTML is replaced. This is the key architectural fact: the map is a persistent JS object manipulated via its API.

**Notable:** Popup HTML is assembled as a JS template string inside `#buildPopupBase()` (lines 486–519), including hardcoded inline styles (`style="text-align:center; margin-top:10px;"`). The "View Full Report" link inside the popup wires a DOM event listener manually because the popup lives outside Stimulus scope (line 380).

**Zoom shortcuts:** Six public methods (`zoom48`, `zoomAk`, `zoomHi`, `zoomPr`, `zoomGu`, `zoomMp`) called via `data-action` attributes — these call `this.map.flyTo(...)` directly.

---

#### `filter_controller.js` (466 lines)

**What it does:** Manages filter dropdown open/close, outside-click dismissal, Apply/Reset, and responsive layout (DOM-reparenting of filter groups into a "More" menu below breakpoints).

**Events listened to:** Document click (for outside-click dismiss).  
**Events dispatched:** `filters:changed` (on Apply and on URL restore).  
**External dependencies:** `filter_state.js` module only.

**How filter state is collected:** `#collectFilters()` (lines 136–220) reads ~30 specific DOM element IDs (`document.getElementById("ws-ground")`, etc.) to reconstruct filter params on every Apply press. No reactive state — the DOM is the source of truth until Apply is clicked.

**DOM restoration:** `#restoreDomState()` (lines 253–352) mirrors `#collectFilters()` in reverse — 100 lines that reconstruct DOM state from URL params on page load. This is tightly coupled to the specific element IDs in `_filter_menus.html.erb`. Adding a new filter requires modifying both methods plus the template.

**Responsive layout:** Uses a `ResizeObserver` on `#container-map`. When the map container narrows past a breakpoint, filter groups are physically moved (via `appendChild`) from their main menu into a "More" dropdown. Four breakpoints: 1190px (Population), 1040px (Compliance), 880px (Boundaries), 730px (Attributes).

---

#### `table_controller.js` (168 lines)

**What it does:** Initializes DataTables on demand (when `table:show` fires), defines 69 column definitions, handles server-side pagination to `/table.json`, and reloads the `turbo-frame#stats-bar` when filters change.

**Events listened to:** `table:show` (dispatched by `nav_controller` when Table section is shown), `filters:changed`.  
**Events dispatched:** None.  
**External dependencies:** `window.DataTable` (DataTables 2.2.2, loaded via CDN `<script>` tag), `filter_state.js` module.

**Stats bar side effect:** `#reloadStatsFrame()` (lines 122–132) sets `turbo-frame#stats-bar`'s `src` attribute to `/public_water_systems/stats?<params>` — this is a Turbo Frame navigation triggered by JS, not by a link click or form submit. DataTables passes the current `FilterState.get()` params merged into each AJAX request.

**Note:** The stats-bar reload belongs conceptually to the map/filter area, not to table initialization. It is triggered on `filters:changed` regardless of whether the table is visible.

---

#### `datasets_controller.js` (96 lines)

**What it does:** Filter and sort the datasets catalog grid. Tracks `sourceFilter` and `frequencyFilter` as instance variables. Hides/shows `.grid-item` divs by toggling `style.display`. Sorts by rearranging DOM nodes with `appendChild`.

**Events listened to:** None (all wired via `data-action`).  
**Events dispatched:** None.  
**External dependencies:** None. Pure vanilla JS.

**No connection to `FilterState`** — this is entirely isolated from the map/table filter system. Self-contained.

---

#### `place_autocomplete_controller.js` (80 lines)

**What it does:** Typeahead search for census places. Debounces input at 250ms, fetches `/places/search?q=`, renders a `<ul>` dropdown, and sets a hidden `#place-geoid` field on selection. Handles blur/mousedown edge case to prevent results from closing before a click registers.

**Events listened to:** None (DOM events only via `data-action`).  
**Events dispatched:** None.  
**External dependencies:** None. Uses `fetch()`.

---

#### `nav_controller.js` (65 lines)

**What it does:** Top-level section navigation. For `map` or `table` sections, hides all `.container-main-content` elements and restores `#container-map`, toggling `.table-mode` class to switch between map and table view via CSS. For other sections (datasets, documentation, downloads), hides everything and shows the target `#container-<section>`. Manages mobile hamburger menu toggle.

**Events listened to:** None (data-action only).  
**Events dispatched:** `table:show` (when section === "table").  
**External dependencies:** None.

**Note:** The mobile menu links in `index.html.erb:240–255` are not wired to `data-action="click->nav#show"` — they are plain `href="javascript:void(0);"` anchors without nav actions. This means mobile section navigation via the mobile menu does not work through the controller.

---

#### `report_controller.js` (31 lines)

**What it does:** Controls the `#container-report` full-page overlay. Shows/hides via `classList.remove/add("hidden")`. Listens for `turbo:frame-load` on the `report-body` frame and populates three header elements from `data-report-field` attributes in the loaded content.

**Events listened to:** `turbo:frame-load` on the frame target.  
**Events dispatched:** None.  
**External dependencies:** None.

---

#### `export_controller.js` (14 lines)

**What it does:** Reads the selected radio input (`data-export-target="format"`), builds a URL from `FilterState.toUrlParams()`, and sets `window.location.href` to trigger a file download.

**Events listened to:** None (data-action only).  
**External dependencies:** `filter_state.js`.

---

#### `slider_controller.js` (8 lines)

**Status: Stub. Not implemented.**

```js
connect() {
  // M6: dual-handle range slider, Highcharts histogram rendering, min/max label updates
}
```

The CSS for sliders exists in `water_tool.css` (lines 828–940), ported from the legacy app. The Stimulus controller exists and is registered but does nothing. There is no Highcharts library loaded.

---

### Identified Issues

**`filter_controller.js` is approaching god-controller territory** (466 lines). It handles: menu toggling, outside-click dismissal, DOM state collection (for Apply), DOM state restoration (for URL params), badge count updates, responsive layout with ResizeObserver, and the responsive DOM-reparenting logic. These are six distinct responsibilities in one class.

**Tight coupling between `filter_controller.js` and `_filter_menus.html.erb`:** `#collectFilters()` and `#restoreDomState()` are mirrors of each other and both reference 30+ specific element IDs by name. Every new filter requires touching both JS methods and the template. No encapsulation.

**`table_controller.js` manages `stats-bar`** — conceptually this belongs to the filter/stats area, not to table initialization.

**Mobile menu links not wired to `nav_controller`** — the mobile navigation overlay (`container-mobile-menu`) has links with no `data-action` attributes, so section switching does not work on mobile via the controller.

---

## 2. Turbo Usage

### Turbo Frames

Two `<turbo-frame>` elements in use:

| Frame ID | Defined in | Populated by | Response template |
|---|---|---|---|
| `stats-bar` | `home/index.html.erb:113` (empty) | `table_controller.js:123–132` sets `frame.src` on `filters:changed` | `public_water_systems/stats/show.html.erb` (10 lines) |
| `report-body` | `home/index.html.erb:223` (empty) | `map_controller.js:385` sets `frame.src` on popup "View Full Report" click | `public_water_systems/reports/show.html.erb` (8 lines) |

**`stats-bar`:** An empty `<turbo-frame>` in the index. When filters change, `table_controller` imperatively sets its `src` to `/public_water_systems/stats?<params>`. Rails responds with `stats/show.html.erb` which wraps its content in `<turbo-frame id="stats-bar">`. CSS rule `turbo-frame#stats-bar:empty { display: none }` hides it until populated. The intro tooltip panel is hidden once `has-stats` class is set on its parent.

**`report-body`:** Empty frame in the report overlay. Populated by a JS-attached click handler inside a Mapbox popup (not a standard Turbo Frame link). The frame loads `/public_water_systems/:pwsid/report` which renders `reports/show.html.erb` inside the frame wrapper, which in turn renders `sections/_all.html.erb` (8 partials).

### Turbo Streams

**Not used anywhere.** No `turbo_stream` responses, no `<turbo-stream>` elements, no ActionCable subscriptions.

### Turbo Drive

**Enabled globally** (Rails default). No `data-turbo-drive="false"` or `data-turbo="false"` attributes found anywhere in the templates. However, this is effectively a single-page application — the entire UI lives on one route (`HomeController#index`), so Turbo Drive never fires a page navigation in normal use. The `data-turbo-track: "reload"` on the stylesheet link in `application.html.erb:36` is the only Turbo-related attribute in the layout.

---

## 3. Existing Component Patterns

### ViewComponent

**Not installed.** No `view_component` gem in the Gemfile or Gemfile.lock. No `app/components/` directory exists. No Lookbook or component preview setup.

### Rails Helpers

`app/helpers/application_helper.rb` is empty (`module ApplicationHelper; end`). No helper methods defined.

### Partials — Full Inventory

**`app/views/home/`** (4 partials):

| Partial | Lines | Used in | What it renders |
|---|---|---|---|
| `_sidebar.html.erb` | 39 | `index.html.erb` | Desktop left-nav panel (logo, section links, EPIC branding, last-updated date) |
| `_filter_menus.html.erb` | 198 | `index.html.erb` | All 6 filter dropdown menus (Source, Attributes, Boundaries, Compliance, Population, More) |
| `_datasets.html.erb` | 671 | `index.html.erb` | Datasets section header + 27 dataset cards (all hardcoded as HTML) |
| `_downloads.html.erb` | 47 | `index.html.erb` | Downloads section with national + per-state S3 download links (loop over array of state codes) |

**`app/views/public_water_systems/sections/`** (8 partials + 1 dispatcher):

| Partial | Lines | Used in | What it renders |
|---|---|---|---|
| `_all.html.erb` | 8 | `reports/show.html.erb`, `show.html.erb` | Renders all 8 section partials below in sequence |
| `_overview.html.erb` | 14 | `_all.html.erb` | PWS identity, source, owner, area, violations count — detail-table |
| `_demographics.html.erb` | 21 | `_all.html.erb` | Population, density, income, poverty, racial demographics — detail-table |
| `_environmental_justice.html.erb` | 19 | `_all.html.erb` | CEJST, SVI, EJScreen, CVI indicators — detail-table |
| `_violations.html.erb` | 26 | `_all.html.erb` | 5-year and 10-year violation counts by category — two-column detail-table |
| `_funding.html.erb` | 13 | `_all.html.erb` | SRF financing counts and amounts — detail-table |
| `_watershed_hazards.html.erb` | 15 | `_all.html.erb` | Upstream hazard indicators — detail-table |
| `_boil_water.html.erb` | 16 | `_all.html.erb` | Boil water notice counts and date range — detail-table |
| `_trends.html.erb` | 31 | `_all.html.erb` | 10-year % change in population, income, poverty, POC — detail-table |

### Partial Organization Assessment

**Home partials are well-scoped** — each maps clearly to a UI section. `_filter_menus.html.erb` is large (198 lines) but it is genuinely one cohesive thing (all filter menus together).

**`_datasets.html.erb` (671 lines) is a maintenance problem.** All 27 dataset cards are hardcoded HTML with repeated structure. Each card is: title, description, callout (source, updated, frequency), bullet list of caveats. A loop over a data structure (YAML file, seeds, or a `datasets` table) would eliminate the duplication. This is the strongest candidate for extraction — either a ViewComponent `DatasetCardComponent` or a data-driven loop.

**Report section partials are clean and consistently structured** — each follows the same `detail-section / if nil / detail-table` pattern. They would be natural ViewComponent candidates (`DetailSectionComponent`) but only if the app adopts ViewComponent.

---

## 4. CSS & Styling Audit

### Tailwind CSS

**Installed but not wired into the layout — effectively unused.**

- Gem: `tailwindcss-rails 4.4.0` / `tailwindcss-ruby 4.2.1` (Tailwind v4)
- Source: `app/assets/tailwind/application.css` (1 line: `@import "tailwindcss"`)
- Output: `app/assets/builds/tailwind.css` (compiled during `bin/dev`)
- **Layout reference: none.** `application.html.erb` only includes `stylesheet_link_tag "water_tool"`. There is no `stylesheet_link_tag "tailwind"` or `stylesheet_link_tag "application"`. The compiled Tailwind output is never served to the browser.
- **Template usage: zero.** No Tailwind utility classes (`flex`, `text-sm`, `px-4`, `bg-`, `grid`, etc.) appear in any template.

A new developer who installs a Tailwind-dependent component will find it has no effect until the layout is updated.

### Custom CSS

**One file, 2,229 lines:**

`app/assets/stylesheets/water_tool.css` — ported from the legacy PHP app (`deprecated/assets/css/styles.css` per the comment header). Contains:

| Section | Approx. lines | Notes |
|---|---|---|
| Body reset, clearfix | 1–28 | Legacy utility classes |
| Tooltip styles (`.tippy-*`) | 29–56 | Tippy.js styles; Tippy is not currently loaded |
| Left nav panel | 57–279 | Sidebar, sidebar nav, active states, icon bg-images |
| Main content layout | 280–309 | `.container-main-content`, map container |
| Map UI | 310–680 | Filter bar, geocoder, AK/HI buttons, info panels, stats bar, map/table toggle |
| Table view | 679–826 | DataTables overrides, `.first-col` sticky, search/pagination |
| Histogram/slider area | 827–940 | Legacy slider CSS (not currently wired to active JS) |
| Filter menus | 941–1280 | `.container-menu`, filter menu footer, filter badge counts |
| Loading mask, filter list | 1697–1760 | `#loading-mask`, `#filter-list-container` |
| Mapbox control overrides | 1750–1895 | Push zoom controls, geocoder, place autocomplete |
| Mapping options / color bar | 1840–1895 | Choropleth legend UI (not currently active) |
| Mobile styles (`@media max-width: 768px`) | 1899–2229 | Full mobile override block ported from legacy `mobile.css` |

`app/assets/stylesheets/application.css` — 11 lines, comment-only manifest file. No declarations, no imports. Effectively empty.

### Other Frameworks

**No Bootstrap, Bulma, or other CSS framework.** Only `water_tool.css`.

**Tippy.js styles are present** (lines 29–56 in `water_tool.css`) but Tippy.js is not loaded in the layout — this CSS is dead code.

**Choropleth legend CSS is present** (`.mapping-options`, `.color-bar-container`, `.key-color*`, lines ~1840–1895) but the feature is not active — these styles appear to be aspirational/future.

### Inline Styles in Templates

Inline `style=` attributes are moderately prevalent:

| Template | `style=` occurrences |
|---|---|
| `home/index.html.erb` | 4 |
| `home/_filter_menus.html.erb` | 9 |
| `home/_sidebar.html.erb` | 4 |
| `home/_datasets.html.erb` | 5 |

Notable instances:
- `_filter_menus.html.erb:16` — `style="position:relative; margin-bottom:10px;"` on the place autocomplete wrapper
- `_filter_menus.html.erb:20` — `style="width:100%; padding:6px 10px; border:1px solid #ccc; border-radius:4px; font-size:0.95em;"` on the text input
- `index.html.erb:19` — `style="display:none;"` on `#filter-list-container`
- `index.html.erb:240` — `style="display:none;"` on `#container-mobile-menu`
- `_sidebar.html.erb:25, 26, 32` — `margin-top:5px;`, `margin:30px 0px;`, `display:none;`
- `map_controller.js:507` — inline style string inside a JS popup HTML builder: `style="text-align:center; margin-top:10px;"`

### CSS Naming Convention

**Consistent BEM-adjacent pattern from the legacy codebase:**
- Container elements: `.container-<name>` (e.g., `.container-map`, `.container-report`, `.container-sidebar-nav`)
- State modifiers as separate classes: `.active`, `.hidden`, `.has-stats`, `.table-mode`
- Component elements: `.filter-menu-btn`, `.btn-filters`, `.btn-apply-filters`
- Icon background images encoded as CSS class + `background: url(...)` pairs

This convention is internally consistent but is not documented and would be unfamiliar to developers coming from Tailwind or BEM.

---

## 5. JavaScript & Asset Pipeline

### Build System

**importmaps** (no Node, no bundler). `config/importmap.rb`:

```ruby
pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "filter_state", to: "filter_state.js"
```

Six pins total. No npm packages, no `node_modules`, no `package.json`.

### CDN-Loaded Libraries (outside importmap)

All loaded via `<script src>` tags directly in `application.html.erb`:

| Library | Version | Why CDN, not importmap |
|---|---|---|
| jQuery | 3.7.1 | Required by DataTables (DataTables 2.x bundles jQuery support but still expects it globally) |
| DataTables | 2.2.2 | UMD bundle depends on global jQuery |
| Mapbox GL JS | 3.14.0 | Large, self-contained, designed for CDN/global use |
| Mapbox Geocoder plugin | 5.1.0 | Depends on `window.mapboxgl` |

**No tree-shaking, no versioning via lock file** for any of these — version upgrades require manual edits to the layout HTML.

### Raw JS Files Outside Controllers

`app/javascript/filter_state.js` (35 lines) — Not a controller, a plain ES module. Acts as a singleton store. Imported by `filter_controller.js`, `table_controller.js`, and `export_controller.js`. Pinned explicitly in importmap.

No other raw JS files exist in `app/javascript/` besides `application.js` (3 lines, just the bootstrap).

### jQuery

**Present — loaded globally from CDN.** However, **jQuery is not referenced anywhere in the Stimulus controllers or in any `<script>` tags in templates.** It exists solely because DataTables 2.x requires it. No `$()` calls, no jQuery selectors, no jQuery event bindings appear in any application JS.

### Inline `<script>` Tags in Templates

The layout (`application.html.erb`) has four CDN `<script src>` tags (jQuery, DataTables, Mapbox GL JS, Mapbox Geocoder) — these are library loads, not application code.

No inline `<script>...</script>` blocks with application logic exist in any template. One `onclick="window.print()"` attribute in `index.html.erb:199` is the only inline JS event handler.

---

## 6. Layout & Template Structure

### Layout Hierarchy

Single layout: `app/views/layouts/application.html.erb` (43 lines). No sub-layouts. The layout:

1. Sets `<title>` from `content_for(:title)` or default
2. Embeds the Mapbox token as `<meta name="mapbox-token">` (read by `map_controller` via `document.head.querySelector`)
3. Loads fonts (Google Fonts: Public Sans)
4. Loads jQuery + DataTables (CDN)
5. Loads Mapbox GL JS + Geocoder (CDN)
6. Links `water_tool.css`
7. Loads importmap JS
8. Renders `<body data-controller="nav">` with `yield`

`nav_controller` is attached to `<body>` — it governs the entire page.

### Home Page Render Tree

`GET /` → `HomeController#index` → `home/index.html.erb` (255 lines):

```
home/index.html.erb
├── (mobile header — inline HTML)
├── (loading mask — inline HTML)
├── (filter-list-container — inline HTML, empty, display:none)
├── render "sidebar"               → home/_sidebar.html.erb (39 lines)
├── #container-map  [data-controller="map filter"]
│   ├── (filter tab bar — inline HTML, 6 buttons)
│   ├── render "filter_menus"      → home/_filter_menus.html.erb (198 lines)
│   │   ├── #container-menu-1  (Source: ground/surface, place autocomplete, protection)
│   │   │   └── [data-controller="place-autocomplete"]
│   │   ├── #container-menu-2  (Attributes: ownership, authority, distribution, facility type)
│   │   ├── #container-menu-3  (Boundaries: type, area range)
│   │   ├── #container-menu-4  (Compliance: violations checkboxes)
│   │   ├── #container-menu-10 (More: funding, watershed hazards — also absorbs collapsed groups)
│   │   └── #container-menu-5  (Population: size categories, density range)
│   ├── #map  (Mapbox GL JS canvas target)
│   ├── #container-ak-hi  (region shortcut buttons — call map#zoom*)
│   ├── #container-map-content-bottom  (intro tooltip, hidden on stats load)
│   ├── <turbo-frame id="stats-bar">  (empty — populated by table_controller on filters:changed)
│   ├── #container-map-ui-bottom  (Map/Table toggle buttons)
│   └── #container-table  [data-controller="table"]
│       └── .table-head-col-2  [data-controller="export"]
│           └── #data-table  (DataTables target)
├── #container-datasets  [hidden]
│   └── render "datasets"          → home/_datasets.html.erb (671 lines)
│       └── [data-controller="datasets"]
├── #container-documentation  [hidden, placeholder only]
├── #container-downloads  [hidden]
│   └── render "downloads"         → home/_downloads.html.erb (47 lines)
├── #container-report  [hidden, data-controller="report"]
│   └── <turbo-frame id="report-body">  (empty — populated on map PWS click)
├── (mobile footer — inline HTML)
└── #container-mobile-menu  (full-screen mobile nav overlay)
```

The entire application is rendered in one pass from one route. Section switching is done by toggling `hidden` classes on `#container-*` divs via `nav_controller`. There are no page navigations.

### View-Specific JS/CSS Coupling

No view-specific JS or CSS includes exist (no `content_for(:head)` blocks in any template, no per-controller asset manifests). All CSS and JS is global.

### Flash Messages, Modals, Overlays

**No flash message UI.** No modal component. The only overlay is `#container-report` — a full-viewport fixed-position div toggled by `report_controller`. It uses `classList.toggle("hidden")` rather than any modal library.

---

## 7. Figma / Asset Integration

### SVG Assets

**No SVG files exist in the project.** No `*.svg` files found under `app/assets/` or anywhere in the app directory.

### Icon System

**All icons are PNG files** served via Propshaft from `app/assets/images/`. Count: ~50 PNG icon files. Many come in dark/white pairs (e.g., `icon-explore-dark.png` / `icon-explore-white.png`).

Icons are used in two ways:
1. **CSS background images** — sidebar nav items use `background: url(icon-explore-dark.png)` with active-state swaps. These are set in `water_tool.css` using relative paths (no `image-url()` helper).
2. **`image_tag` helpers** — used directly in templates for inline icons (e.g., `image_tag "icon-close.png"`).

No SVG sprite, no icon font, no Heroicons, no Lucide.

### Image Asset Pipeline

**Propshaft** serves all images directly from `app/assets/images/`. No Active Storage. No CDN for images. No image optimization or transformation pipeline (though `image_processing` gem is in the Gemfile, it appears to be there as a default Rails scaffold dependency, not actively used).

---

## 8. Identified Pain Points

### Structural Pain Points

**1. `filter_controller.js` has mirrored collect/restore logic.**  
`#collectFilters()` reads DOM → params. `#restoreDomState()` reads params → DOM. These are the same mapping written twice in opposite directions, 100+ lines each. Every new filter requires modifying both, and the template. A single declarative filter config (an object describing each filter, its DOM id, its param name, its default) would eliminate the duplication.

**2. `_datasets.html.erb` is 671 lines of repeated HTML.**  
27 dataset cards, each hand-written. Same four-part structure (title, description, callout, bullet list) repeated 27 times with minor variations. No loop. No data structure. Adding dataset 28 requires copying a card block and editing multiple fields manually.

**3. Popup HTML is built via JS template strings in `map_controller.js`.**  
`#buildPopupBase()` (lines 486–519) assembles HTML with hardcoded inline styles. This is the only place where server-rendered and client-rendered HTML coexist in a conflated way. If the popup design changes, it requires editing JS, not a template.

**4. Mobile navigation is not connected to `nav_controller`.**  
`#container-mobile-menu` (index.html.erb:240–255) lists navigation links as plain `href="javascript:void(0);"` anchors without `data-action`. The mobile menu shows/hides (`nav_controller#toggleMobile`) but the nav items inside it don't trigger section switching. The nav links in the sidebar ARE wired (`data-action="click->nav#show"`); the mobile overlay duplicates the link list but without the wiring.

**5. `slider_controller.js` is registered but empty.**  
The controller exists, is auto-loaded, and is presumably referenced somewhere in the filter HTML (the slider CSS classes exist in `water_tool.css`). No slider UI is currently active, but the CSS for it (`container-hc`, `slider-container`, `range-slider`, etc.) remains in the stylesheet — dead CSS until M6 lands.

**6. Tailwind is installed but not served.**  
`tailwindcss-rails` is in the Gemfile, the source file exists, and `bin/dev` will build `tailwind.css`. But the layout does not reference it. A developer who tries to use Tailwind utilities will see no effect until the layout is updated and knows to look for this.

**7. Duplicate navigation lists.**  
Desktop sidebar (`_sidebar.html.erb`) and mobile menu overlay (inline in `index.html.erb:240–255`) both contain the navigation link list. These must be kept in sync manually. Documentation section links to an external PDF in sidebar but shows a placeholder `<h3 class="placeholder">Documentation</h3>` in the in-app content panel.

**8. `table_controller` manages the stats Turbo Frame.**  
`#reloadStatsFrame()` is called on `filters:changed` from `table_controller`. Conceptually the stats bar belongs to the map/filter area, not to table initialization. This creates a hidden dependency: if `table_controller` is ever refactored or moved, the stats bar reload breaks silently.

### TODO / In-Progress Markers in Code

| Location | Content |
|---|---|
| `slider_controller.js:3` | `// Manages range slider inputs with histogram display — full implementation in M6.` |
| `slider_controller.js:6` | `// M6: dual-handle range slider, Highcharts histogram rendering, min/max label updates` |
| `_filter_menus.html.erb:2` | `<%# Full filter wiring happens in M6 (depends on M3 PWS API). These are structural shells. %>` |
| `_filter_menus.html.erb:119` | Boil water notices filter: `disabled="disabled"`, label class `filter-coming-soon`, `(data unavailable)` |
| `_filter_menus.html.erb:142` | Annual water and sewer bill: `disabled="disabled"`, `filter-coming-soon`, `(TBD)` |
| `index.html.erb:182` | Documentation section: `<h3 class="placeholder">Documentation</h3>` — empty section |

### CSS Dead Code

- **Tippy.js styles** (`water_tool.css:29–56`) — Tippy.js is not loaded
- **Slider / histogram CSS** (`water_tool.css:827–940`) — active in legacy, not yet rewired in Stimulus
- **Choropleth legend CSS** (`water_tool.css:1840–1895`) — future feature not yet built
- **`.filter-list-container`** (`water_tool.css:1716–1759`) — the filter tag list (`#filter-list`) is always `display:none` in the HTML with no code ever showing it

---

## 9. Summary Statistics

| Metric | Value |
|---|---|
| Total Stimulus controllers | 9 (+ 1 JS module: `filter_state.js`) |
| Total partials | 13 |
| Total ViewComponents | 0 |
| Custom CSS files | 1 (`water_tool.css`, 2,229 lines) |
| JS bundler | importmaps (no Node, no npm, no bundler) |
| Tailwind installed | Yes (tailwindcss-rails 4.4.0 / Tailwind v4) |
| Tailwind actually loaded in browser | **No** — not referenced in layout |
| Tailwind utility classes in templates | **Zero** |
| jQuery present | Yes — jQuery 3.7.1 (CDN), required only by DataTables |
| jQuery used in app code | **No** — never called directly |
| Frontend test coverage | **None** — RSpec covers backend only |
| Inline `<script>` blocks with app logic | **None** |
| SVG icon system | **None** — all icons are PNG |
| ViewComponent gem | **Not installed** |
| Lookbook | **Not installed** |
| Turbo Streams | **Not used** |
| Turbo Drive | Enabled globally (single-route app — never fires) |

---

## 10. Architecture Observations for the Hotwire vs. React Decision

The audit surfaces a few facts that should directly inform the choice:

**The map is already a pure JS object layer, regardless of path.** `this.map = new window.mapboxgl.Map(...)` lives in a Stimulus controller today. In React it would live in a component. In either case, filter changes → fetch `/map` → `this.map.setFilter(...)`. The Mapbox GL JS API calls are identical. This part of the app is framework-neutral.

**The DOM-reading filter collection pattern is a Hotwire-specific pain.** `filter_controller#collectFilters()` manually reads 30 DOM element IDs because Stimulus has no reactive state. In React, filter state would be a single `useState` object, and `#restoreDomState` would not exist (state initialization from URL params is one-directional). The mirrored collect/restore duplication is not an inherent problem of Hotwire but is a consequence of building stateful UI with DOM-as-truth.

**DataTables and jQuery are the legacy anchor.** The only reason jQuery is loaded is DataTables. Replacing DataTables with a Turbo Frame table (Hotwire path) or a React data grid (React path) eliminates jQuery entirely. Both paths produce the same improvement.

**Tailwind being installed but unused is a low-effort fix.** Adding `stylesheet_link_tag "tailwind"` to the layout would enable it immediately. Whether to actually use it depends on whether `water_tool.css` gets replaced or extended.

**`_datasets.html.erb` is the strongest near-term target** regardless of path. The 671-line hardcoded card list should become data-driven. In Hotwire: a loop over a YAML config or `Dataset` model, rendered as a partial or ViewComponent. In React: the same data rendered as a component list.
