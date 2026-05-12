# Asset and CSS Deprecation Guide

_Last updated: 2026-05-12 — filter menu Tailwind pass + doc sync_

This document tracks the migration away from legacy image assets and `water_tool.css` toward a clean, Tailwind-only frontend. It serves as both a record of decisions made and a step-by-step implementation guide for future work sessions.

---

## Section 1: Image Asset Migration ✅ COMPLETE

### What was done

We are currently using `SVG` assets exclusively, and should continue to follow that pattern if possible.
- **`app/assets/svgs/`** — all SVG icons, read by the `icon()` helper via `File.read`

Other directories were deleted:
- `app/assets/dwet_design_system_svgs/` — unused design system exports, including one fake SVG that embedded a PNG via base64.
- `app/assets/images/icons/` — the intermediate consolidation directory, replaced by the split above.
- All legacy root-level images (`logo-drinking-water-explorer.png`, `EPIC-logo.png`, `icon-map.jpg`, etc.).
- Territory/state SVGs (`alaska.svg`, `hawaii.svg`, `pr.svg`, `gu.svg`, `mp.svg`) — territory buttons use plain text, no SVGs needed.

### How icons are used

| Pattern | Example | When to use |
|---|---|---|
| `icon()` helper | `<%= icon("arrow-down", classes: "h-4 w-4") %>` | All SVG icons — inlines SVG, supports `text-*` color via `fill="currentColor"` |

### Logo SVGs (replaced PNGs) ✅ COMPLETE

All three logo PNGs have been replaced with SVGs via the `icon()` helper (`app/assets/svgs/`):

| SVG file | Replaces | Used in |
|---|---|---|
| `water.svg` | `water-logo.png`, `mobile-water-logo.png` | `_sidebar.html.erb`, `index.html.erb` mobile header, `reports/show.html.erb` |
| `epic.svg` | `epic-logo-small.png` | `_sidebar.html.erb`, `index.html.erb` mobile footer |

**Notes:**
- SVGs must use inline `fill` attributes (not embedded `<style>` blocks) to avoid CSS class collisions when multiple SVGs are inlined on the same page.
- The `icon()` helper strips uppercase from filenames — `epic.svg` not `EPIC.svg`.

### Current SVG inventory (`app/assets/svgs/`)

**Active (used via `icon()` helper):**

| File | Where used |
|---|---|
| `arrow-down.svg` | `_filter_menus.html.erb` (expandable rows), `filters/range_filter_item_component.html.erb` |
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
| `info.svg` | `_filter_menus.html.erb`, `filters/range_filter_item_component.html.erb` (tooltips) |
| `map.svg` | `index.html.erb` map/table toggle |
| `mobile-menu.svg` | `index.html.erb` mobile header |
| `nav-arrow-down.svg` | `index.html.erb` filter tabs ×6 |
| `print.svg` | `index.html.erb` report print button |
| `table.svg` | `index.html.erb` map/table toggle |

**Present but unreferenced** (keep for future use, delete if never wired up):

`arrow-downward.svg`, `arrow-upward.svg`, `locate.svg`, `map-filters.svg`, `nav-arrow-up.svg`, `navigation-hover.svg`, `navigation-on.svg`, `search.svg`, `sort.svg`, `tooltip-down.svg`, `tooltip-up.svg`, `zoom-in.svg`, `zoom-out.svg`

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

**NOTE:** There also appears to be a `mobile.css` file which needs to be deprecated as well. We DO NOT want to have a seperate CSS config for mobile in our app, rather we want to write things in a 'mobile friendly' way. See `A11Y_AND_MOBILE_GUIDE.md` for any guidance here if needed.

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
**Status:** ✅ Complete

**CSS classes removed:**
`.container-nav-panel`, `#toggle-button`, `#toggle-button:hover`, `.container-logo`, `.container-intro`, `.container-intro h2/p`, `.container-sidebar-nav`, `.container-sidebar-bottom`, `.container-sidebar-bottom a/img`, `.container-main-content` (layout rule), `#container-ak-hi` and variants (renamed)

**What was done:**
- Full `_sidebar.html.erb` rewrite: legacy CSS class names → Tailwind utilities on every element.
- Sidebar is a floating card: `fixed top-2 left-4 bottom-8 rounded-xl shadow-md overflow-y-auto overflow-x-hidden` — visible map gap on all sides.
- Interior layout is `flex flex-col` (replaces pixel-locked `position: absolute` for logo, intro, nav, and bottom sections).
- New **`sidebar_controller.js`** (Stimulus): handles expand/collapse toggle, viewport-based auto-collapse below 1280px, localStorage persistence, and shifts `#container-map-ui-top`, `.mapboxgl-ctrl-top-left`, and `#container-region-nav` horizontally when width changes.
- Toggle button shows `collapse.svg` when open and `expand.svg` when closed, using `group-data-[sidebar-collapsed]:hidden` and `group-[&:not([data-sidebar-collapsed])]:hidden` (avoids Tailwind v4 `hidden` cascade conflict).
- Logo and intro containers stay in the DOM when collapsed (using `invisible` + `overflow-x-hidden` + `min-w-[250px]` on text containers to prevent layout shift from text reflow at narrow width).
- `.container-main-content` `left: 250px` → `left: 0` (sidebar now overlays the map, not pushing it).
- `#container-ak-hi` renamed to `#container-region-nav` (covers 48 states + territories).

**Files updated:** `_sidebar.html.erb`, `sidebar_controller.js` (new), `water_tool.css`, `index.html.erb`

**Tailwind v4 cascade gotchas encountered:**
- `hidden md:flex` conflict: fix with `max-md:hidden md:flex` (scope each to non-overlapping media queries).
- `hidden group-data-[...]:block` conflict: fix with `group-[&:not([...])]:hidden` (negation variant avoids the collision entirely).

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
**Status:** 🔶 Partially complete

**CSS to remove:**
`.container-main-content`, `#container-map`, `#map`

**Migration:**
- `.container-main-content` `left: 250px` removed — sidebar now overlays the map (Chunk C). All four `.container-main-content` divs in `index.html.erb` now have Tailwind `w-full absolute left-0`; the CSS rule has been deleted. ✅
- `#container-map` is `position: absolute; inset: 0` — replace with Tailwind `absolute inset-0`. ⬜
- `#map` is `width: 100%; height: 100%` → Tailwind `w-full h-full`. ⬜
- **Do remaining items after Chunk D** — mobile pixel values inform these dimensions.

**Files to update:** `index.html.erb`

**Test:** Map fills available space at all viewport sizes. No white gaps, no overflow. Sidebar and map don't overlap. Switching between map and table view works.

---

#### Chunk F: Filter bar and filter menus
**Status:** 🔶 Partially complete

**Done (2026-05 — dropdown shell + inner menu chrome):**
- **`UI::FilterMenuComponent`** / **`UI::FilterTabComponent`** — outer panels use Tailwind (including `.filter-dropdown` / `.filter-dropdown-more`). Legacy **class names** `.container-menu` / `.container-menu-more` are no longer used for presentation; **element IDs** stay `container-menu-*` for `filter_menu_controller.js` and `filter_layout_controller.js`. Per-tab **filter count badges** use Tailwind on `FilterTabComponent`; JS keeps the `container-filter-count-menu-{id}` class hook for updates.
- **`_filter_menus.html.erb`** — section headings, lists, and row `<li>` elements carry Tailwind utilities inline (no Ruby helper for class strings).
- **`Filters::RangeFilterItemComponent`** — root `<li>` uses the same utility bundle as simple filter rows.
- **Population vs “Size” heading** when `#container-menu-5-items` is reparented into the More menu — implemented with Tailwind arbitrary parent variants (`[.filter-dropdown-more_&]:…`) on the two `<h3>`s; no `.visible-in-more` / `.visible-in-main` rules in `application.css`.
- **Scrollbars** — Firefox: arbitrary `scrollbar-width` / `scrollbar-color` on the component; WebKit: `.filter-menu-scroll::-webkit-scrollbar*` in `app/assets/tailwind/application.css` (pseudo-elements cannot be utilities).
- **`water_tool.css` cleanup for this slice** — removed dead `.filter-cat-indent`; removed `.container-menu h2.map-filter-mobile-header` (More menu `<h2>` uses Tailwind on the element).

**Still open (same chunk — grep `water_tool.css` before migrating):**
- Filter chrome still in legacy CSS: `.container-population-filter-grid`, `.container-water-sewer-bill-filter-grid`, `.pop-size-box`, `.wsb-box`, `.dropdown-selectors`, `.rounded-checkbox`, `.filter-coming-soon`, `.container-filter`, `.btn-filters`, `.btn-reset-filters`, `.btn-apply-filters`, `.btn-filter-options img`, `.filter-menu-footer`, `.filters-desktop-display`, mobile filter rules (`#mobile-btn-filters`, `.filter-menu-mobile`, etc.), `.slider-subhead` if still present.
- **Historical list** (many already gone or renamed): `#container-map-ui-top` is positioned via Tailwind in `index.html.erb`; `.container-menu*` **presentation** migrated as above; `.filter-cat-indent` deleted; `.visible-in-*` handled via utilities on headings.

**Migration (remaining work):**
- Population / WSB segmented controls and `.dropdown-selectors` → Tailwind on the underlying `<button>` / `<select>` nodes (or small components if the markup stabilizes).
- `.rounded-checkbox` — still styled in `water_tool.css`; migrate appearance to utilities or keep a minimal `@layer` hook if browser defaults fight the design.
- Number spinner suppression — only if/when visible `type="number"` inputs return to filter UI; prefer Tailwind arbitrary variants or a scoped rule.

**Files:** `_filter_menus.html.erb`, `index.html.erb`, `app/components/ui/filter_menu_component.*`, `app/components/filters/range_filter_item_component.*`, `app/javascript/controllers/filter*.js`, `water_tool.css`, `app/assets/tailwind/application.css`

**Test:** All six filter tabs + More menu open/close; responsive reparenting into More; Apply/Reset; population size tiles; tooltips on range rows; no scrollbar regression in WebKit/Firefox.

---

##### TODO (refactor): ViewComponent candidates for `_filter_menus.html.erb`

_Not required to finish Chunk F, but high ROI once menu markup churn slows down. Prefer components for **repeated structure + Stimulus wiring**, not for hiding Tailwind strings (utilities stay in the component template)._

1. **Expandable subcategory parent row** — `<li>` + checkbox with `change->filter#toggleSubcat` + label + optional info tooltip + chevron `click->filter#toggleSubcatPanel` + `hidden` `data-subcat-panel` wrapper + nested `<ul>`. Copy-pasted across Compliance and More menus; easy to mis-wire `data-panel-id` / `aria-*`.
2. **`UI::FilterMenuSectionHeadingComponent`** (name TBD) — `h2` / `h3` with `variant: :main | :more` and optional `extra_classes:` for one-offs (Population dual headings, mobile “More filters” bar).
3. **`UI::FilterMenuListComponent`** — optional thin wrapper for the repeated `<ul class="my-[6px] …">` if the partial stays hard to scan.

Ship **Lookbook previews + specs** for any new public UI component per project norms.

---

#### Chunk G: Mapbox GL overrides ⚠️ Extract, do not delete
**Status:** ⬜ Not started (note: base **geocoder** chrome already duplicated in `app/assets/tailwind/application.css` as `.mapboxgl-ctrl-geocoder.mapboxgl-ctrl` — reconcile when extracting so rules are not split across three places forever)

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
