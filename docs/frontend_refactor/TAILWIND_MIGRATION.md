# Asset and CSS Deprecation Guide

_Last updated: 2026-05-17 — Chunk A complete; hide-for-\* classes migrated to Tailwind group variants; application.css deleted_

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

`app/assets/stylesheets/water_tool.css` (~648 lines remaining as of 2026-05-12) - the legacy stylesheet ported from an older codebase. The goal is to migrate all styles to Tailwind utility classes applied directly in HTML/ERB templates, then delete the file entirely.

The file is already partially migrated — several blocks were removed in earlier sessions (DataTables, dataset cards, report sections, tippy, slider histograms). See the removal log at the top of the file.

**May 2026 dead-code sweep (Tier 4, `chore/remove-more-dead-css`):** Selectors were removed only after a static check that they had **no references under `app/`** (views, components, Stimulus, specs). References confined to `deprecated/` were treated as non-blocking for the Rails app. `bin/ci` was run green on the branch. Remaining risk is the usual caveat for class names built only at runtime (none were observed for the removed sets).

**May 2026 follow-up (Tier 5):** Additional **Rails-only** dead hooks removed from `water_tool.css`: `#wrapper-ui`, `#wrapper-map-ui` (no matching elements in the app), `#container-zoom-to-loc` and descendants (legacy PHP-only markup), and the **first** duplicate `.mapboxgl-ctrl-geolocate` block bundled with that shell (the surviving override is under “Mapbox control overrides”). **`deprecated/` was not modified** — the snapshot still includes `deprecated/assets/css/mobile.css` and `deprecated/index.php` still links it; Rails does not load that path.

**Paused (2026-05-12):** Further **large-scale** deletion from `water_tool.css` is on hold. What remains is largely still tied to live UI; the next wins follow the **chunk** plan below (Tailwind migration + targeted QA), not another blind CSS purge.

**Notable removals (Rails-facing `water_tool.css` only):**

- **Map popups:** `.map-hover-*`, unused `.map-detail-body a.btn-report` (live popup uses `js-view-report` + inline styles in `map_controller.js`).
- **Legacy map UI:** `.green-bar`, `.bwn-content-wrapper`, `.filters-desktop-display`.
- **Population pills only:** dropped water/sewer bill grid (`.container-water-sewer-bill-filter-grid`, `.wsb-*`, `.wsb-1line`) and kept `.pop-size-box` / `.container-population-filter-grid` rules only.
- **Old filter menu chrome:** `.filter-menu-footer`, `.btn-filters`, `.btn-reset-filters`, `.btn-apply-filters`, `.container-category-header`, `.container-filter`, `.btn-filter-options img`.
- **Report shell:** empty `#container-report .header` and unused `.header-logo` / `.header-title` / `.id-logo` / `.id-text` / `#container-report .header p` (report header is Tailwind in `public_water_systems/reports/show.html.erb`).
- **Other:** `.hide-this`, `.slider-subhead`.
- **Mobile `@media (max-width: 640px)`:** unused hooks (e.g. `.container-region-nav-mobile`, `.filters-mobile-display`, `.filter-menu-mobile`, `.mobile-header-map-filters`, duplicate `.filter-menu-footer`, `#mobile-btn-*`, `.btn-close-map-info`, `.map-content-wrapper-mobile`) and collapsed stats positioning into a **single** `.map-content-stats` rule (still used from `public_water_systems/stats/show.html.erb`).

**Files touched (May 2026 cleanup + doc):**

| File | What changed |
|------|----------------|
| `app/assets/stylesheets/water_tool.css` | Tier 4 + Tier 5 removals; changelog in file header. |
| `docs/frontend_refactor/TAILWIND_MIGRATION.md` | This guide (accuracy + pause + `mapbox_overrides` stance). |

**Not touched (by policy):** `deprecated/**` — treated as a **read-only legacy snapshot** (including `deprecated/assets/css/mobile.css` for the old PHP app). Rails continues **not** to load that path; mobile for the live app is `water_tool.css` `@media (max-width: 640px)` + Tailwind.

### Progress log (housekeeping vs. chunk checklist)

Chunk **Status** lines below (**Not started** / **Partially complete** / **Complete**) mean **“Tailwind + templates own this area end-to-end”** (or the chunk’s defined scope is done). **Do not flip a chunk to ✅** just because dead rules were deleted from `water_tool.css` — that’s maintenance on a file we’re still carrying.

| When | What happened |
|------|-----------------|
| **2026-05** | **Tier 4 — `water_tool.css`:** Removed selectors with **no live references under `app/`** (map-hover popup chrome, BWN/green-bar, old filter footer/button classes, water/sewer bill grid, orphan report header hooks, `.hide-this`, `.slider-subhead`, unused mobile-only hooks in `@media (max-width: 640px)`; see Section 2 overview bullets). `bin/ci` green on branch. |
| **2026-05** | **Tier 5 — `water_tool.css`:** Removed `#wrapper-ui`, `#wrapper-map-ui`, `#container-zoom-to-loc` (+ nested rules), and a duplicate `.mapboxgl-ctrl-geolocate` block. **`deprecated/` not modified** (snapshot policy). |
| **2026-05** | **Section-mode architecture + section cards (branch: `fix/datasets-page-multiple-fixes`):** Introduced `.section-mode` CSS class on `#container-map` (alongside existing `.table-mode`) so map always stays visible as a decorative background in all views. `nav_controller.js` refactored: JS show/hide replaced with CSS class toggling; map canvas never hidden. `sidebar_controller.js` extended: section containers (`#container-datasets`, `#container-documentation`, `#container-downloads`, `#container-table`) shift right of sidebar on collapse/expand. Section containers and table container given Tailwind card classes (`top-3 bottom-8 rounded-xl shadow-lg`). `.container-section-inner` wrapper class removed from `water_tool.css` and all HTML; `_downloads.html.erb` fully migrated to Tailwind. `#container-map.table-mode #map { display: none }` removed — map now stays visible as background in table mode. Dead CSS removed: `#container-datasets`, `.datasets-header h3`. Section-mode overlay rules added to `application.css`. |
| **2026-05** | **Tier 6 — CSS cleanup (branch: `fix/datasets-page-multiple-fixes`):** `#container-map` and `#map` desktop CSS removed → Tailwind `bg-[#ccc] absolute inset-0` / `w-full h-full` on elements in `index.html.erb`. Stats-bar + intro tooltip migrated to Tailwind: `.map-content-wrapper-desktop`, `.map-content-intro`, `.map-content-stats`, `ul.stats-list`, `#container-map-content-bottom h2/p` all removed from `water_tool.css`; `turbo-frame#stats-bar` and intro tooltip markup updated to inline Tailwind. `.table-scroll` scrollbar rules (Firefox + WebKit) moved to `application.css` alongside `.filter-menu-scroll`. `#container-map.table-mode .mapboxgl-ctrl-top-left` moved to `application.css` (consolidated with section-mode geocoder rule). Dead CSS removed: `.clear`/`.clearfix`, `.container-main-content h3.placeholder`, `#container-table { background-color }` (redundant with higher-specificity nested rule), `.hidden` (Tailwind provides this). |
| **2026-05-17** | **Chunk A complete — global visibility utilities (branch: `feat/datasets-page-cleanup-work`):** All `hide-for-*` legacy classes removed from `water_tool.css` and replaced with Tailwind directly on elements. `hide-for-desktop` → `sm:hidden`; `hide-for-mobile` → `max-[640px]:hidden`; `hide-for-table` → `group-[.table-mode]:hidden`; `hide-for-section` (was in `application.css`) → `group-[.section-mode]:hidden`. `group` class added to `#container-map` to support group-based conditional visibility. Redundant `@media (max-width:640px)` rules also removed: `#container-map-ui-bottom { display:none }` (now `max-[640px]:hidden`), `.mm-icon-bars`/`.mm-icon-x` (default display + `hidden` on icon in HTML). `app/assets/stylesheets/application.css` deleted entirely; `stylesheet_link_tag "application"` removed from layout. |

### General approach

- **Work section by section, matching app UI areas.** Each chunk maps to a visible area of the app — easier to test and less likely to cause cross-area regressions.
- **Start with global utilities (Chunk A)** — visibility classes cut across all views and are the easiest win with the highest impact.
- **After each chunk:** run `bin/ci`, then do a manual visual pass on affected views at both desktop and mobile widths.
- **Mapbox overrides (Chunk G)** — these target vendor-injected DOM and cannot be replaced with Tailwind utilities on our own elements. **Default plan:** keep a **minimal** vanilla CSS block co-located (today: mostly `water_tool.css`, with some geocoder overlap in `tailwind/application.css` — reconcile when touching this area). **Optional escape hatch:** a dedicated `mapbox_overrides.css` (see Chunk G) **only if we need it** — it is **not** an ideal end state (extra asset, load-order coupling, rules splintered across files). Prefer staying in one place until `water_tool.css` goes away.
- When a CSS class is removed from `water_tool.css`, also remove or replace every occurrence of it in views/partials.

---

### Chunks

#### Chunk A: Global visibility utilities
**Status:** ✅ Complete

**What was done:**
- `hide-for-desktop` → `sm:hidden` on `.mobile-header` and `.mobile-footer` in `index.html.erb`
- `hide-for-mobile` → `max-[640px]:hidden` on `container-region-nav`, `container-map-ui-bottom` intro tooltip, `container-map-ui-bottom` toggle, and the "More filters" `<h2>` in `_filter_menus.html.erb`
- `hide-for-table` → `group-[.table-mode]:hidden` on `container-region-nav` and `container-map-content-bottom` in `index.html.erb`
- `hide-for-section` (was `application.css`) → `group-[.section-mode]:hidden` on `container-map-ui-bottom` in `index.html.erb`
- `group` class added to `#container-map` to enable all `group-[...]` variants above
- `.hide-when-collapsed` / `.hide-when-collapsed-fade` — these never existed in Rails; sidebar uses `group-data-[sidebar-collapsed]:hidden` / `group-[&:not([data-sidebar-collapsed])]:hidden` (Chunk C)
- All three CSS rules removed from `water_tool.css`; redundant `@media` rules (`#container-map-ui-bottom`, `.mm-icon-bars`, `.mm-icon-x`) also cleaned up
- `app/assets/stylesheets/application.css` deleted; `stylesheet_link_tag "application"` removed from layout

**Files updated:** `index.html.erb`, `_filter_menus.html.erb`, `water_tool.css`, `layouts/application.html.erb`

---

#### Chunk B: Base and body styles
**Status:** 🔶 Partially complete

**CSS to remove:**
`body {}` (`#wrapper-ui` / `#wrapper-map-ui` removed in May 2026; `.clear` / `.clearfix` removed in May 2026 — no live float layouts.)

**Migration:**
- `body` font family is declared in `app/assets/tailwind/application.css` — verify Tailwind preflight covers margin/padding/font and delete the duplicate.

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

---

##### Mobile/Desktop Audit (2026-05-17)

The sections below map every mobile-only / desktop-only pattern currently in the app to a concrete Tailwind migration path.

**Already handled by Tailwind — no further work needed:**

| Element | Current Tailwind | Note |
|---|---|---|
| `#container-map` mobile offset | `max-[640px]:fixed max-[640px]:top-[60px] max-[640px]:bottom-[50px]` | ✅ |
| `#container-map-ui-top` hidden on mobile | `max-[640px]:hidden` | ✅ |
| `#container-region-nav` hidden on mobile | `max-[640px]:hidden` | ✅ |
| `#container-map-ui-bottom` toggle hidden on mobile | `max-[640px]:hidden` | ✅ (CSS rule also removed from `@media` block) |
| Sidebar hidden on mobile | `max-[640px]:hidden` on `_sidebar.html.erb` root | ✅ |
| `.mobile-header` / `.mobile-footer` hidden on desktop | `sm:hidden` | ✅ (was `hide-for-desktop` — Chunk A) |
| `.mm-icon-x` hidden initially | `hidden` class on element in HTML | ✅ (JS nav controller toggles it — CSS rule removed) |

**Still in `water_tool.css` @media block — needs Tailwind migration (Chunk D work):**

| CSS selector | Current rule | Tailwind migration |
|---|---|---|
| `.mobile-header` | `fixed top-0 w-full bg-white text-center z-[9999] p-3` (box-sizing, floats layout) | Replace float layout with: `fixed inset-x-0 top-0 z-[9999] flex items-center justify-between px-3 py-2 bg-white` on the element. Remove float children (see below). |
| `.mobile-header h1` | `display:inline-block; font-size:1.2em; font-weight:500; color:#25325b; padding-top:4px` | Add to `<h1>`: `text-xl font-medium text-[#25325b] m-0 pt-1` |
| `.mobile-header .m-header-left` | `float:left` | `<div class="m-header-left">` → just a flex child; no class needed once parent is `flex` |
| `.mobile-header .m-header-right` | `float:right` | Same — remove float, flex parent handles layout |
| `.mobile-header .m-header-right a` | `display:inline-block; padding:6px 8px 6px 6px` | Add to the `<a>`: `inline-flex p-1.5` |
| `.mobile-footer` | `fixed bottom-0 w-full bg-[#1054A8] text-center z-[99999] px-2.5 py-2.5` | `fixed inset-x-0 bottom-0 z-[99999] bg-[#1054A8] text-center px-2.5 py-2.5` on element |
| `.mobile-footer img` | `margin-top: -20px` | Add `-mt-5` to the `<%= icon "epic" %>` call |
| `.mobile-footer p` | `color:#fff; margin:0; font-size:.9em` | Add `text-white m-0 text-sm` to `<p>` elements |
| `.container-main-content` (mobile) | `position:fixed; top:60px; left:0; right:0; bottom:50px; overflow-y:auto` | Add `max-[640px]:fixed max-[640px]:inset-x-0 max-[640px]:top-[60px] max-[640px]:bottom-[50px] max-[640px]:overflow-y-auto` to each `container-main-content` section (`#container-datasets`, `#container-documentation`, `#container-downloads`). Note: `#container-map` already has these classes. Once all four elements have explicit Tailwind, the CSS rule and `.container-main-content` class can both be removed. |
| `#container-mobile-menu` | `fixed left-0 bg-white w-full h-full z-[999] overflow-scroll` | Already uses `style="display:none"` controlled by JS. Add Tailwind: `fixed inset-0 z-[999] bg-white overflow-y-scroll hidden`. Update `nav_controller.js` to toggle `hidden` instead of setting `style.display`. |
| `.container-mobile-menu-inner` | `padding:60px 20px` | Add `px-5 pt-[60px] pb-[60px]` to the `<div class="container-mobile-menu-inner ...">` — class already partially migrated to Tailwind (`flex flex-col min-h-full`). Remove class once padding is inline. |

**`nav_controller.js` changes needed (for `#container-mobile-menu`):**
The menu currently uses `menu.style.display = "block"` / `"none"`. Once the element has `hidden` in HTML, switch to:
```js
menu.classList.remove("hidden")  // was: menu.style.display = "block"
menu.classList.add("hidden")     // was: menu.style.display = "none"
```

---

**CSS classes to remove from `water_tool.css`:**
`.mobile-header` (and descendants), `.mobile-footer` (and descendants), `.container-main-content` media rule, `#container-mobile-menu`, `.container-mobile-menu-inner`

**After completing Chunk D**, the entire `@media (max-width: 640px)` block in `water_tool.css` will be empty and can be deleted.

**Files to update:** `index.html.erb` (mobile header, footer, and menu sections), `nav_controller.js`

**Test:** On mobile: fixed header visible at top, hamburger opens full-screen menu, footer pinned at bottom. No overlap between header/map/footer. On desktop: mobile elements hidden, no layout shift.

---

#### Chunk E: Core app layout (map + main content containers)
**Status:** ✅ Complete

**CSS removed:**
- `.container-main-content` CSS rule (Chunk C) ✅
- `#container-map` → Tailwind `bg-[#ccc] absolute inset-0 max-[640px]:fixed max-[640px]:top-[60px] max-[640px]:bottom-[50px]` on element in `index.html.erb` ✅
- `#map` → Tailwind `w-full h-full` on element ✅

**Files updated:** `index.html.erb`

---

#### Chunk F: Filter bar and filter menus
**Status:** ✅ Complete — Tailwind owns the dropdown shell and all filter content. `water_tool.css` has no remaining filter rules.

**Done (2026-05 — dropdown shell + inner menu chrome):**
- **`UI::FilterMenuComponent`** / **`UI::FilterTabComponent`** — outer panels use Tailwind (including `.filter-dropdown` / `.filter-dropdown-more`). Legacy **class names** `.container-menu` / `.container-menu-more` are no longer used for presentation; **element IDs** stay `container-menu-*` for `filter_menu_controller.js` and `filter_layout_controller.js`. Per-tab **filter count badges** use Tailwind on `FilterTabComponent`; JS keeps the `container-filter-count-menu-{id}` class hook for updates.
- **`_filter_menus.html.erb`** — section headings, lists, and row `<li>` elements carry Tailwind utilities inline (no Ruby helper for class strings).
- **`Filters::RangeFilterItemComponent`** — root `<li>` uses the same utility bundle as simple filter rows.
- **Population vs “Size” heading** when `#container-menu-5-items` is reparented into the More menu — implemented with Tailwind arbitrary parent variants (`[.filter-dropdown-more_&]:…`) on the two `<h3>`s; no `.visible-in-more` / `.visible-in-main` rules in `application.css`.
- **Scrollbars** — Firefox: arbitrary `scrollbar-width` / `scrollbar-color` on the component; WebKit: `.filter-menu-scroll::-webkit-scrollbar*` in `app/assets/tailwind/application.css` (pseudo-elements cannot be utilities).

**Done (May 2026 — Chunk F complete):**
- Deleted **legacy-only** rules that had no live `app/` references (old filter footer / apply-reset buttons, water/sewer bill grid, orphan shells, etc.); see **Progress log**.
- **`Filters::PopSizePillComponent`** (new) — encapsulates the 5 population size pills with Tailwind border/radius position logic and active-state variants. `container-population-filter-grid` wrapper replaced with `flex` + spacing utilities. `pop-size-box` and related CSS rules deleted.
- **`dropdown-selectors`** wrapper replaced with `mb-5`; Tailwind utilities added directly to each `<select>`.
- **`.filter-coming-soon`** replaced with `text-[#888]` on the label.
- **`.rounded-checkbox`** — class kept as a JS hook only (referenced by `filter_controller.js`). Inline Tailwind applied directly to the `<input>`: `size-4 rounded-full border border-neutral-400 appearance-none` (unchecked circle) + `checked:appearance-auto checked:[clip-path:circle(50%_at_50%_50%)] checked:bg-brand-dark checked:accent-[#13171F]` (checked: native widget clipped to circle). **Do not add `.rounded-checkbox` rules to `application.css`** — inline utilities are the pattern here.
- **Filter bar pointer-events fix** — `#container-map-ui-top` (`pointer-events-none`) + `<ul#filter-tabs>` (`pointer-events-none`) + each `<li>` in `UI::FilterTabComponent` (`pointer-events-auto`). The full-width transparent overlay was swallowing clicks to the Mapbox geocoder beneath the empty left half of the bar.
- **`UI::FilterTabComponent` height** — `min-h-11` → `h-10` to match the Mapbox geocoder's `height: 40px` set in `tailwind/application.css`.

**Historical list** (all resolved): `#container-map-ui-top` is positioned via Tailwind in `index.html.erb`; `.container-menu*` **presentation** migrated as above; `.filter-cat-indent` deleted; `.visible-in-*` handled via utilities on headings; `.active`/`.active-first` CSS rules were dead (targeted `a`, pills are `button` — handled by `[&.active]:` variants).

**Files:** `_filter_menus.html.erb`, `index.html.erb`, `app/components/ui/filter_menu_component.*`, `app/components/filters/range_filter_item_component.*`, `app/javascript/controllers/filter*.js`, `water_tool.css`, `app/assets/tailwind/application.css`

**Test:** All six filter tabs + More menu open/close; responsive reparenting into More; Apply/Reset; population size tiles; tooltips on range rows; no scrollbar regression in WebKit/Firefox.

---

##### TODO (refactor): ViewComponent candidates for `_filter_menus.html.erb`

_Not required to finish Chunk F, but high ROI once menu markup churn slows down. Prefer components for **repeated structure + Stimulus wiring**, not for hiding Tailwind strings (utilities stay in the component template)._

**Note (May 2026):** `UI::CircleButtonComponent` was extracted during `chore/remove-more-dead-css` — all circular button patterns (sidebar toggle, report overlay print/close, map region shortcuts) now delegate to it. Items 1–3 below are unrelated filter-menu TODOs that remain pending.

1. **Expandable subcategory parent row** — `<li>` + checkbox with `change->filter#toggleSubcat` + label + optional info tooltip + chevron `click->filter#toggleSubcatPanel` + `hidden` `data-subcat-panel` wrapper + nested `<ul>`. Copy-pasted across Compliance and More menus; easy to mis-wire `data-panel-id` / `aria-*`.
2. **`UI::FilterMenuSectionHeadingComponent`** (name TBD) — `h2` / `h3` with `variant: :main | :more` and optional `extra_classes:` for one-offs (Population dual headings, mobile “More filters” bar).
3. **`UI::FilterMenuListComponent`** — optional thin wrapper for the repeated `<ul class="my-[6px] …">` if the partial stays hard to scan.

Ship **Lookbook previews + specs** for any new public UI component per project norms.

---

#### Chunk G: Mapbox GL overrides ⚠️ Keep minimal vanilla CSS; optional `mapbox_overrides.css` only if needed
**Status:** ⬜ Not started (note: base **geocoder** chrome already duplicated in `app/assets/tailwind/application.css` as `.mapboxgl-ctrl-geocoder.mapboxgl-ctrl` — reconcile when touching this area so rules are not split across three places forever)

**Preferred approach:** Leave Mapbox-facing rules in **`water_tool.css`** (or consolidate into **`tailwind/application.css`** only where it genuinely fits, e.g. small geocoder tweaks) until the stylesheet is deleted. Tailwind cannot replace styling **inside** Mapbox’s injected DOM without fragile hacks.

**Optional — `app/assets/stylesheets/mapbox_overrides.css` (escape hatch, not ideal):** Splitting vendor CSS into a second file is **not** the preferred architecture — it adds another `stylesheet_link_tag`, ordering concerns next to `"tailwind"` / `"water_tool"`, and encourages permanent fragmentation across `water_tool.css`, `application.css`, and a third file. **Consider this only if** we hit a concrete need (e.g. shrinking `water_tool.css` for reviewability, clearer ownership, or isolating vendor rules for a specific refactor). If we add it: one-time audit for duplicate selectors, then **one** canonical home per concern.

**CSS to move to `mapbox_overrides.css` *if* we adopt the escape hatch:**
All `.mapboxgl-*` rules, `.place-autocomplete-results`, `.mapboxgl-ctrl-geocoder`, `.mapboxgl-ctrl-group`, `.mapboxgl-ctrl-top-left`, `.infoBub`, `.map-content-wrapper-desktop`, `.map-content-intro`, `.map-content-stats`, `turbo-frame#stats-bar:empty`, `#container-map-content-bottom`, `#container-map.table-mode` rules.

**Already deleted from `water_tool.css` (not moved — unused by Rails):** `.green-bar`, `.bwn-content-wrapper`, `.map-content-wrapper-mobile`, `#mobile-btn-info`, `#mobile-btn-filters` (these only appeared in `deprecated/` assets).

**Incidental update (May 2026):** `.mapboxgl-ctrl-group button:first-child, button:last-child` `width`/`height` updated 31px → 32px and border color `#bfbfbf` → `#d1d5db` to match `UI::CircleButtonComponent` standard size.

**Migration (if using `mapbox_overrides.css`):**
- Mapbox GL JS injects DOM at runtime — Tailwind cannot target those nodes with utilities on our templates.
- Create `app/assets/stylesheets/mapbox_overrides.css`, move the rules above, and add `stylesheet_link_tag "mapbox_overrides"` to `app/views/layouts/application.html.erb` **after** Tailwind / before or after `water_tool` per cascade needs — verify once.
- Do not try to “Tailwind-ify” Mapbox’s internal class names.

**Migration (default — no new file):** Keep rules in `water_tool.css`; delete them only when the map feature is removed or styles are proven obsolete.

**Test:** Map renders correctly. Popup appears on click with correct styling (rounded corners, padding). Geocoder search shows dropdown suggestions. Zoom +/- controls styled correctly. Stats bar shows/hides on filter. Table-mode toggle hides map controls correctly.

---

#### Chunk H: Table view
**Status:** 🔶 Partially complete

**Already done:**
- `#container-map.table-mode .hide-for-table { display: none }` → removed from `water_tool.css`; all `hide-for-table` usages replaced with `group-[.table-mode]:hidden` (Chunk A, 2026-05-17)
- `.table-scroll` scrollbar rules → `tailwind/application.css`
- `#container-table { background-color: #fff }` standalone rule removed (covered by nested selector)
- `#container-map.table-mode .mapboxgl-ctrl-top-left` → `tailwind/application.css`

**CSS still to remove from `water_tool.css`:**
`#container-map #container-table` (display/position/z-index block), `#container-map.table-mode #container-table` (flex show rule).

**Migration:**
- `#container-map #container-table` display logic: replace `display:none` default + `display:flex` in table-mode with Tailwind `hidden`/`flex` class toggling (already done via `.table-mode` CSS — migrate the CSS rule itself).
- `#container-table` position/z-index → Tailwind `absolute z-[3]` on the element.

**Files to update:** `index.html.erb`, possibly the map-table-toggle Stimulus controller

**Test:** Map/Table toggle switches views. Table fills the space where the map was. Custom scrollbar visible on table overflow. Switching back to map re-renders Mapbox without error.

---

#### Chunk I: Report view
**Status:** ✅ Complete

**Completed (May 2026):**
- All legacy report CSS removed from `water_tool.css`: `#container-report`, `.container-report-section-inner`, `.container-report-body`, `.container-report-body h2` (dead — no h2 in report views), and the full `.btn-report` family
- `#container-report` → `hidden fixed inset-0 z-[9999] bg-white overflow-y-auto print:static print:h-auto print:overflow-visible` (inline Tailwind, `index.html.erb`)
- `.container-report-section-inner` → `mx-auto max-w-[1200px] border border-[#eee] bg-white p-10 mt-[30px] mb-[50px] print:border-0 print:p-0 print:mt-0 print:mb-0` (inline Tailwind, `index.html.erb`)
- `.container-report-body` wrapper removed; it only existed to offset the `60px` margin-top override
- Print and close buttons → `UI::CircleButtonComponent` with `print:hidden`
- `report_controller.js` → `print()` method replaces legacy `onclick`
- `reports/show.html.erb` header: logo always `w-[85px]`, DWE text always visible, `grid-cols-[1fr_2fr_1fr]`, date/time stamp right-aligned
- Print layout via `content_for :head` in `index.html.erb`: `@page` with 0.5in margins and custom page count at `@bottom-right`; `body > *:not(#container-report)` hides non-report content on print — `@page` at-rules and complex selectors can't be Tailwind utilities, so `content_for :head` is the conventional Rails home for them

**Files updated:** `app/views/home/index.html.erb`, `app/views/public_water_systems/reports/show.html.erb`

**Completed (May 2026):** `.container-section-inner` removed from `water_tool.css` (shared with Chunk J — coordinated). No remaining CSS for this chunk.

**Test:** Report opens as full-screen overlay. Print button hidden on print; triggers browser dialog on click. Close button dismisses report. Multi-page printing works with 0.5in margins and "X of Y" page count at bottom-right. Logo, date/time, and utility name render correctly on page 1.

---

#### Chunk J: Downloads section
**Status:** ✅ Complete

**CSS removed:** `.container-section-inner`, `#container-downloads .container-section-inner` (desktop + mobile blocks, including `.grid-conatiner` float layout). All removed from `water_tool.css`.

**Migration done:** `_downloads.html.erb` fully rewritten with Tailwind (`max-w-2xl`, `grid grid-cols-2 md:grid-cols-4`, etc.). `#container-downloads` in `index.html.erb` uses Tailwind card classes directly (no `.container-section-inner` wrapper).

---

#### Chunk K: Loading mask and remaining utilities
**Status:** ⬜ Not started

**CSS to remove:**
`#loading-mask` (`.datasets-header h3` and `#container-datasets` were removed in May 2026 — both dead CSS with no live references.)

**Migration:**
- `#loading-mask` is `position: absolute; background: rgba(0,0,0,0.6); z-index: 1002` → Tailwind `absolute inset-0 bg-black/60 z-[1002] text-center`.

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
