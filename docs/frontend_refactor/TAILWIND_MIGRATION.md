# Asset and CSS Deprecation Guide

_Last updated: May 2026_

This document tracks the migration away from legacy image assets and `water_tool.css` toward a clean, Tailwind-only frontend. It serves as both a record of decisions made and a step-by-step implementation guide for future work sessions.

---

## Section 1: Image Asset Migration ✅ COMPLETE

### What was done

Assets are split into two locations by type:

- **`app/assets/svgs/`** — all SVG icons, read by the `icon()` helper via `File.read`
- **`app/assets/images/`** — PNG logos only, served by the asset pipeline via `image_tag`

Other directories were deleted:
- `app/assets/dwet_design_system_svgs/` — unused design system exports, including one fake SVG that embedded a PNG via base64.
- `app/assets/images/icons/` — the intermediate consolidation directory, replaced by the split above.
- All legacy root-level images (`logo-drinking-water-explorer.png`, `EPIC-logo.png`, `icon-map.jpg`, etc.).
- Territory/state SVGs (`alaska.svg`, `hawaii.svg`, `pr.svg`, `gu.svg`, `mp.svg`) — territory buttons use plain text, no SVGs needed.

### How icons are used

| Pattern | Example | When to use |
|---|---|---|
| `icon()` helper | `<%= icon("arrow-down", classes: "h-4 w-4") %>` | All SVG icons — inlines SVG, supports `text-*` color via `fill="currentColor"` |
| `image_tag` | `<%= image_tag "water-logo.png" %>` | PNG logos only — no color theming needed |

### Current PNG files in use

These three logo PNGs are intentionally kept as raster files for now (`app/assets/images/`):

| File | Used in |
|---|---|
| `water-logo.png` | `_sidebar.html.erb`, `reports/show.html.erb` |
| `mobile-water-logo.png` | `index.html.erb` mobile header |
| `epic-logo-small.png` | `_sidebar.html.erb`, `index.html.erb` mobile footer |

> **Future:** These could be replaced with true vector SVGs if the design team provides properly exported source files (not PNG-embedded fakes). When that happens, switch to `icon()` helper and remove the PNGs. Not a priority until the files are available.

### Current SVG inventory (`app/assets/svgs/`)

**Active (used via `icon()` helper):**

| File | Where used |
|---|---|
| `arrow-down.svg` | `_filter_menus.html.erb` ×4 |
| `close.svg` | `index.html.erb` report close button |
| `collapse.svg` | `_sidebar.html.erb` toggle |
| `data.svg` | `_sidebar.html.erb`, `index.html.erb` mobile menu |
| `documentation.svg` | `_sidebar.html.erb`, `index.html.erb` mobile menu |
| `downloads.svg` | `_sidebar.html.erb`, `index.html.erb` mobile menu, table export |
| `email.svg` | `_sidebar.html.erb` ×2, `index.html.erb` mobile menu |
| `expand.svg` | `_sidebar.html.erb` toggle |
| `explore.svg` | `_sidebar.html.erb`, `index.html.erb` mobile menu |
| `external-link.svg` | `_sidebar.html.erb` ×3, `index.html.erb` mobile menu ×3 |
| `feedback.svg` | `index.html.erb` mobile menu |
| `filter.svg` | `_datasets.html.erb` |
| `github.svg` | `index.html.erb` mobile menu |
| `map.svg` | `index.html.erb` map/table toggle |
| `mobile-menu.svg` | `index.html.erb` mobile header |
| `nav-arrow-down.svg` | `index.html.erb` filter tabs ×6 |
| `print.svg` | `index.html.erb` report print button |
| `table.svg` | `index.html.erb` map/table toggle |

**Present but unreferenced** (keep for future use, delete if never wired up):

`arrow-downward.svg`, `arrow-upward.svg`, `info.svg`, `locate.svg`, `map-filters.svg`, `nav-arrow-up.svg`, `navigation-hover.svg`, `navigation-on.svg`, `search.svg`, `sort.svg`, `tooltip-down.svg`, `tooltip-up.svg`, `zoom-in.svg`, `zoom-out.svg`

---

## Section 2: Deprecating `water_tool.css`

### Overview

`app/assets/stylesheets/water_tool.css` (~1,400 lines) is the legacy stylesheet ported from an older codebase. The goal is to migrate all styles to Tailwind utility classes applied directly in HTML/ERB templates, then delete the file entirely.

The file is already partially migrated — several blocks were removed in earlier sessions (DataTables, dataset cards, report sections, tippy, slider histograms). See the removal log at the top of the file.

### General approach

- **Work section by section, matching app UI areas.** Each chunk maps to a visible area of the app — easier to test and less likely to cause cross-area regressions.
- **Start with global utilities (Chunk A)** — visibility classes cut across all views and are the easiest win with the highest impact.
- **After each chunk:** run `bin/ci`, then do a manual visual pass on affected views at both desktop and mobile widths.
- **Mapbox overrides are a special case (Chunk G)** — these target vendor-injected DOM and cannot be replaced with Tailwind. Extract them to a dedicated `mapbox_overrides.css` rather than deleting.
- When a CSS class is removed from `water_tool.css`, also remove or replace every occurrence of it in views/partials.

---

### Chunks

#### Chunk A: Global visibility utilities
**Status:** ⬜ Not started

**CSS classes to remove from `water_tool.css`:**
`.hide-for-desktop`, `.hide-for-mobile`, `.hide-when-collapsed`, `.hide-when-collapsed-fade`, `.hide-this`, `.hidden`

**Migration:**
- `hide-for-desktop` → `md:hidden`
- `hide-for-mobile` → `hidden md:block`
- `hide-when-collapsed` / `hide-when-collapsed-fade` → driven by the `nav` Stimulus controller; switch to a Tailwind `group` or `data-collapsed` attribute + Tailwind variant so the controller sets a data attribute and CSS responds to it
- `.hidden` → Tailwind `hidden` (confirm no naming collision)

**Files to update:** `_sidebar.html.erb`, `index.html.erb`, `_filter_menus.html.erb`

**Test:** Desktop sidebar collapses/expands, hiding the correct elements. On mobile, sidebar is hidden and mobile header/menu appear. No flash of wrong content on load.

---

#### Chunk B: Base and body styles
**Status:** ⬜ Not started

**CSS to remove:**
`body {}`, `#wrapper-ui {}`, `.clear`, `.clearfix`

**Migration:**
- `body` font family is declared in `app/assets/tailwind/application.css` — verify and delete the duplicate.
- `.clear` / `.clearfix` — grep views; almost certainly unreferenced. Delete if so.
- `#wrapper-ui` — likely a no-op wrapper; confirm and remove from both CSS and HTML if unused.

**Test:** Page font rendering unchanged. No layout collapse on any view.

---

#### Chunk C: Sidebar layout
**Status:** ⬜ Not started

**CSS classes to remove:**
`.container-nav-panel`, `#toggle-button`, `.container-logo`, `.container-intro`, `.container-intro h2/p`, `.container-sidebar-nav`, `.container-sidebar-bottom`, `.container-sidebar-bottom a/img`

**Migration:**
- Sidebar is `position: fixed; width: 250px; height: 100%` — replace with Tailwind `fixed w-[250px] h-full overflow-y-auto` on the `<aside>` in `_sidebar.html.erb`.
- `#toggle-button` is a circular 32px button with absolute positioning — replace with Tailwind on the actual `<button>` element.
- `.container-intro` uses `position: absolute; top: 152px` — this pixel-locked value is fragile. When migrating, consider switching the sidebar interior to a flex column layout instead of absolute positioning.

**Files to update:** `_sidebar.html.erb`

**Test:** Sidebar renders at correct width. Logo, intro text, nav links, and bottom section all display correctly. Toggle button visible and functional. Sidebar scrolls when content overflows.

---

#### Chunk D: Mobile shell (header, footer, menu overlay)
**Status:** ⬜ Not started

**CSS classes to remove:**
`.mobile-header`, `.mobile-header h1/img/a`, `.m-header-left`, `.m-header-right`, `.mobile-footer`, `.mobile-footer img/p`, `#container-mobile-menu`, `.container-mobile-menu-inner`, `.mm-icon-bars`, `.mm-icon-x`

**Also:** The entire `@media (max-width: 768px)` block that repositions `.container-main-content` and `#container-map` for mobile viewports.

**Migration:**
- Mobile header: `position: fixed; top: 0; width: 100%` → Tailwind `fixed top-0 inset-x-0 z-[9999] bg-white`.
- Mobile footer: `position: fixed; bottom: 0` → same pattern.
- The media query shifts `#container-map` and `.container-main-content` to account for 60px header and 50px footer — use Tailwind `md:` prefix to toggle between mobile and desktop positioning.
- `mm-icon-bars` / `mm-icon-x` visibility is driven by the `nav` Stimulus controller — keep JS logic, switch to Tailwind `hidden` class toggling.

**Files to update:** `index.html.erb` (mobile header, footer, and menu sections)

**Test:** On mobile: fixed header visible at top, hamburger opens full-screen menu, footer pinned at bottom. No overlap between header/map/footer. On desktop: mobile elements hidden, no layout shift.

---

#### Chunk E: Core app layout (map + main content containers)
**Status:** ⬜ Not started

**CSS to remove:**
`.container-main-content`, `#container-map`, `#map`

**Migration:**
- `.container-main-content` is `position: absolute; left: 250px` — offset by sidebar width. Replace with Tailwind `absolute left-[250px]` or use a flex layout on the page wrapper.
- `#container-map` is `position: absolute; inset: 0` — replace with Tailwind `absolute inset-0`.
- `#map` is `width: 100%; height: 100%` → Tailwind `w-full h-full`.
- **Do this chunk after Chunk C and Chunk D** — mobile and sidebar pixel values inform these dimensions.

**Files to update:** `index.html.erb`, `_sidebar.html.erb` (structural wrappers)

**Test:** Map fills available space at all viewport sizes. No white gaps, no overflow. Sidebar and map don't overlap. Switching between map and table view works.

---

#### Chunk F: Filter bar and filter menus
**Status:** ⬜ Not started

**CSS classes to remove:**
`#container-map-ui-top`, `.container-map-ui ul/li`, `.geocoder-li`, `.filters-desktop-display`, `.container-menu`, `.container-menu h2/h3/p/ul/li`, `.container-filter-count`, `.container-menu-inner`, `.filter-menu-footer`, `.btn-filters`, `.btn-reset-filters`, `.btn-apply-filters`, `.visible-in-more`, `.container-category-header`, `.container-menu-more`, `.filter-cat-indent`, `.filter-coming-soon`, `.container-menu-more ul li a`, `.container-menu input` (number spinner suppression), `.container-menu-more #container-menu-5-items`, `.container-filter`, `.pop-size-box`, `.wsb-box`, `.container-population-filter-grid`, `.container-water-sewer-bill-filter-grid`, `.dropdown-selectors`, `.rounded-checkbox`, `.slider-subhead`

**Migration:**
- Filter tab buttons (`filter-menu-btn`) are already fully Tailwind — skip those.
- `.container-filter-count` (green active-filter badge) and `.btn-filters` / `.btn-apply-filters` (Reset/Apply) are the highest-priority visible elements.
- Population and WSB filter boxes use a segmented button pattern — replaceable with Tailwind border/rounded utilities.
- Number spinner suppression (`-webkit-appearance: none`) — move to a Tailwind `[&::-webkit-outer-spin-button]:appearance-none` variant or a small utility block in `application.css`.
- `.rounded-checkbox` — grep for usage first; if still active, migrate to Tailwind or a small ViewComponent.

**Files to update:** `_filter_menus.html.erb`, `index.html.erb`

**Test:** All 6 filter tabs open/close correctly. Active tab shows blue/white styling. Filter count badge appears when filters are active. Apply/Reset buttons function. Population size boxes selectable. Mobile filter sheet opens/closes. Number inputs don't show browser spinners.

---

#### Chunk G: Mapbox GL overrides ⚠️ Extract, do not delete
**Status:** ⬜ Not started

**CSS to move to `app/assets/stylesheets/mapbox_overrides.css`:**
All `.mapboxgl-*` rules, `.place-autocomplete-results`, `.mapboxgl-ctrl-geocoder`, `.mapboxgl-ctrl-group`, `.mapboxgl-ctrl-top-left`, `.infoBub`, `.green-bar`, `.bwn-content-wrapper`, `.map-content-wrapper-desktop`, `.map-content-intro`, `.map-content-stats`, `turbo-frame#stats-bar:empty`, `#container-map-content-bottom`, `#container-map.table-mode` rules, `.map-content-wrapper-mobile`, `#mobile-btn-info`, `#mobile-btn-filters`

**Migration:**
- Mapbox GL JS injects DOM at runtime — Tailwind cannot target vendor elements.
- Move these rules to a new file `app/assets/stylesheets/mapbox_overrides.css`.
- Add `stylesheet_link_tag "mapbox_overrides"` to `app/views/layouts/application.html.erb` alongside the existing stylesheet links.
- Do not try to replace these with Tailwind — leave them as vanilla CSS in the new file.

**Test:** Map renders correctly. Popup appears on click with correct styling (rounded corners, padding). Geocoder search shows dropdown suggestions. Zoom +/- controls styled correctly. Stats bar shows/hides on filter. Table-mode toggle hides map controls correctly.

---

#### Chunk H: Table view
**Status:** ⬜ Not started

**CSS to remove:**
`#container-table`, `.table-scroll` (custom scrollbar), `#container-map #container-table`, `#container-map.table-mode *` rules (after moving to mapbox_overrides in Chunk G)

**Migration:**
- `#container-table` show/hide is toggled by `.table-mode` on `#container-map` (via the map-table-toggle Stimulus controller). Keep the JS; migrate the CSS display logic to Tailwind `hidden` class toggling.
- `.table-scroll` scrollbar styling — Tailwind v4 has `scrollbar-thin`, `scrollbar-color-*` utilities; use those, or keep as a small utility block in `application.css` if browser support is a concern.

**Files to update:** `index.html.erb`, possibly the map-table-toggle Stimulus controller

**Test:** Map/Table toggle switches views. Table fills the space where the map was. Custom scrollbar visible on table overflow. Switching back to map re-renders Mapbox without error.

---

#### Chunk I: Report view
**Status:** ⬜ Not started

**CSS to remove:**
`#container-report`, `.btn-report`, `.btn-print-report`, `.btn-close-report`, `.btn-print-report img`, `.btn-close-report img`, `.container-report-section-inner`, `.container-section-inner`, `.container-report-section-inner .header-logo/header-title`

**Migration:**
- `#container-report` is `position: fixed; inset: 0; z-index: 9999; overflow-y: auto` → Tailwind `fixed inset-0 z-[9999] bg-white overflow-y-auto`.
- `.btn-report` is a circular 40px fixed-position button — shared base for print and close buttons. Replace with Tailwind on the button elements in `reports/show.html.erb`.

**Files to update:** `app/views/public_water_systems/reports/show.html.erb`

**Test:** Report opens as full-screen overlay. Print button triggers browser print dialog. Close button dismisses report. Logo and header visible at top. Report content scrollable.

---

#### Chunk J: Downloads section
**Status:** ⬜ Not started

**CSS to remove:**
`#container-downloads .container-section-inner` and its descendant rules

**Migration:**
- Note the typo in the CSS: `.grid-conatiner` (not "container") — grep for this in views to locate the actual element.
- Mostly margin, width, and float-based grid layout. Replace with Tailwind flex/grid utilities.

**Files to update:** Downloads view — locate with `grep -r "container-downloads" app/views/`

**Test:** Downloads section renders with correct layout at desktop and mobile widths. Links accessible and correct.

---

#### Chunk K: Loading mask and remaining utilities
**Status:** ⬜ Not started

**CSS to remove:**
`#loading-mask`, `.container-filter p`, `.btn-filter-options img`, `.datasets-header h3`, `#container-datasets`

**Migration:**
- `#loading-mask` is `position: absolute; background: rgba(0,0,0,0.6); z-index: 1002` → Tailwind `absolute inset-0 bg-black/60 z-[1002] text-center`.
- Grep each remaining class before migrating — some may already be dead.

**Test:** Loading mask appears during map data fetch, disappears when complete.

---

### Finishing up

Once all chunks are complete and checked off:

1. Confirm `water_tool.css` contains only comments or is empty.
2. Remove `stylesheet_link_tag "water_tool"` from `app/views/layouts/application.html.erb`.
3. Delete `app/assets/stylesheets/water_tool.css`.
4. Run `bin/ci` — full suite must pass.
5. Full visual pass: desktop sidebar collapsed/expanded, mobile menu, all filter tabs, table view, report overlay, downloads.

---

## Special Case: Favicon

`public/icon.png` is referenced in `layouts/application.html.erb` and `pwa/manifest.json.erb` as the browser favicon/PWA icon. Browser convention — not part of this migration.
