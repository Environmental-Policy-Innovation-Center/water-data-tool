# Misc Changes Worklog

Temporary scratch notes for branch `chore/misc-changes` (worktree: `water-data-tool-misc`).
Delete or fold into PR description before merge.

Each section below describes one logical change on this branch.

---

## Report (shareable URL, overlay, components)

**Summary:** Utility reports use one URL (`/public_water_systems/:pwsid/report`). From the map, a normal click opens the report in an overlay via Turbo Frame (map stays on `/`, filters/zoom preserved) with **print** and **close (X)**. Shareable flows (copy link, Cmd/Ctrl+click, new tab, pasted URL) open a standalone full-page report with **print** and **back-to-map** (no overlay close button).

**Added**
- `layouts/report.html.erb` — standalone report page (styles, print, back-to-map)
- `Report::HeaderComponent`, `Report::SectionHeadingComponent` (+ Lookbook previews, component specs)
- `public_water_systems/reports/_report_content.html.erb` — shared report body
- Request/component specs for reports

**Changed**
- Map popup “View Full Report” — real `href` (copyable/shareable); normal click opens overlay; modified clicks navigate to the report URL
- `home/index.html.erb` — report overlay: `turbo-frame#report-body`, print + close (X)
- `map_controller.js`, `report_controller.js` — overlay open/close, `Turbo.visit` into frame
- `reports_controller.rb` — full layout for direct visits; no layout for Turbo Frame requests
- `show.html.erb` — always wraps content in `<turbo-frame id="report-body">` (same template for overlay and full page)
- `detail_section_component` — uses `Report::SectionHeadingComponent`

**Removed / not used**
- Iframe-based report embed and `report_embedded?` helper (reverted after Turbo Frame fix)

**How to test**

Automated:
```bash
bundle exec rspec spec/requests/reports_spec.rb spec/components/report/
```

Manual (`PORT=3001 bin/dev` if the main worktree uses 3000):
1. Map → zoom to a PWS → popup → hover link shows `/public_water_systems/…/report`
2. Normal click → overlay opens, address bar stays on `/`, report styled, print and close work
3. Right-click → copy link → open in new tab → full report page with print and back-to-map
4. Cmd/Ctrl+click → new tab with same full report page
5. Optional: compound `pwsid` — link and encoded URL both load

**Notes**
- **Controls:** map overlay = print + close (`report_controller`); standalone `layouts/report` = print + `link_to` back to map (not Stimulus close).
- Requires built Tailwind locally: `bin/rails tailwindcss:build` once per worktree, or run `bin/dev` (watch handles it). CI precompiles assets.
- No Stimulus/JS tests for map popup click wiring — manual check only.
- Standalone back link uses `data-turbo="false"` so return to `/` does not hang (report layout has no Turbo Drive).
- Future: optional per-section `Report::*SectionComponent`s; section partials under `sections/` unchanged as glue.

**PR notes** (report slice — paste/adapt for multi-domain PR)

Makes utility reports a first-class, shareable resource while keeping the existing map workflow. The map popup link is a real URL (copyable, hoverable, works with Cmd/Ctrl+open-in-new-tab) instead of `javascript:void(0)`. A normal click still opens the report on top of the map so users do not lose filter or zoom state; share and bookmark flows use the same path as a standalone printable page with its own layout and styles. Map overlay: print + close (X). Standalone page: print + back-to-map link.

Implementation uses Turbo Frame in the overlay (same pattern as stats/table), not an iframe. One report template wraps content in `turbo-frame#report-body` for both overlay loads and full-page visits; the controller only varies layout (fragment vs `layouts/report`). Report header and section headings are extracted into ViewComponents (`Report::HeaderComponent`, `Report::SectionHeadingComponent`) so overlay and standalone views stay in sync and section headings stay consistent with `UI::DetailSectionComponent`.

**Reviewer focus:** map popup click behavior (overlay vs new tab), standalone report page when opening `/public_water_systems/:pwsid/report` directly, compound/encoded `pwsid` routing. Specs: `spec/requests/reports_spec.rb`, `spec/components/report/`.

---

## A11y — filters & table export

**Status:** Done on this branch (manual QA complete). Independent of Report slice; safe to review/merge separately in a multi-PR split.

**Summary:** Replace fake navigation (`href="#"`, `javascript:void(0)`) with real controls where the UI runs an action, not a route. Table **Export** is a `<button>`. Source filter **Place** search is an accessible combobox with keyboard support and strict selection semantics. Dynamic markup uses ERB `<template>` + clone (HTML-first); focus ring via `focus_ring_classes` helper.

**Added**
- `app/views/home/_map_popup_template.html.erb` — Mapbox PWS popup shell (`data-map-target="popupTemplate"`)

**Changed**
- `app/helpers/application_helper.rb` — `focus_ring_classes` helper (ERB access to `FOCUS_RING_CLASSES`)
- `app/views/home/index.html.erb` — Export `<button>` + `focus_ring_classes`; renders `map_popup_template` partial inside `#container-map`
- `app/views/home/_filter_menus.html.erb` — Place combobox ARIA; option row `<template>`; list `max-h-48 overflow-y-auto z-[1000]`; input `data-[pulse]:bg-neutral-100`
- `app/javascript/controllers/place_autocomplete_controller.js` — combobox behavior (see Notes); clones option template; no styling constants in JS
- `app/javascript/controllers/map_controller.js` — clones popup template; fills fields with `textContent`; toggles optional sections (type, report link)
- `docs/ARCHITECTURE.md` — `place_autocomplete_controller` blurb updated (was stale: wrong menu, debounce, responsibilities)

**Removed / not used**
- `href="#"` and `javascript:void(0)` in active `app/` UI (none remain)
- Duplicated `FOCUS_RING_CLASSES` / `OPTION_CLASSES` in `place_autocomplete_controller.js`
- Inline popup HTML strings and `#escapeHtml` in `map_controller.js`
- JS `#updateResultsMaxHeight` (replaced by fixed Tailwind `max-h-48` — conventional combobox pattern)

**How to test**

Manual (`PORT=3001 bin/dev` if the main worktree uses 3000):

*Export*
1. Table view → choose `.csv` or `.geojson` → **Export** → download from `/public_water_systems/export?…`
2. Hover Export → no status-bar URL (expected for buttons)
3. Tab to Export → Enter still triggers download

*Place combobox (Source → Place)*
1. Type ≥2 chars → list opens (`max-h-48`, scrollable); stacks above Reset/Apply (`z-[1000]`)
2. Mouse: pick a row → input + `#place-geoid` set → Apply filters by place
3. Keyboard: ↓/↑ highlights row (list scrolls); Enter selects; Escape closes; Tab skips options → next control
4. ↑ from first highlight → no row selected; brief gray input pulse (`data-pulse`, 200ms)
5. Type without picking (e.g. `Tamp`) → click outside or Apply → input clears; no `place_geoid` in filters
6. Pick a place → edit text → `place_geoid` clears until a new pick

*Map popup (template refactor — styling unchanged)*
1. Zoom to PWS → hover popup shows state / connections / population
2. Click PWS → popup includes type + “View Full Report” link with focus ring
3. Normal click report link → overlay; Cmd/Ctrl+click → new tab (Report section)

**Notes**
- **Semantics:** Actions use `<button>`; navigation uses real `href` (see Report section). Matches `docs/A11Y_AND_MOBILE_GUIDE.md`.
- **Place combobox implementation:**
  - `mousedown` `preventDefault` on results list — prevents input blur **before** click completes (selection still closes list via `select()` → `#hideResults()`).
  - `focusout` + deferred check — closes list when focus leaves widget (Tab outside, click outside); not meant to keep list open after a pick.
  - `filters:changed` listener — clears orphan input text on Apply when no `place_geoid`.
  - Debounce **250ms**; API returns max **10** places (`PlacesController#search`).
- **Place pulse:** Optional UX; `data-[pulse]:bg-neutral-100` in ERB + 200ms toggle in JS (same pattern as `data-[active]` elsewhere).
- **Dropdown height:** Fixed `max-h-48` + internal scroll (not JS-measured). List may overlap sticky footer visually when Place field is low; close list before Apply if needed.
- **Markup pattern:** `<template>` in views; Stimulus sets text, `data-*`, ARIA only (`TAILWINDS_CSS_GUIDE.md`).
- No new automated specs — manual only.
- Requires Tailwind build/watch so `data-[pulse]:bg-neutral-100` is in the bundle.

**PR notes** (a11y slice — paste/adapt for multi-domain PR)

Closes flagged follow-ups for fake links on table Export and place autocomplete dropdown rows. Export remains a Stimulus download (`export#download`); only the element type and focus ring change. Place search is an accessible combobox: options are `<button>` elements cloned from an ERB template; keyboard navigation uses `aria-activedescendant`; Tab skips the list; partial text without a valid `place_geoid` clears on dismiss or Apply. Map PWS popup markup moved to `_map_popup_template.html.erb` (same UX, fields via `textContent`). Dropdown: fixed `max-h-48`, scroll, `z-[1000]` above sticky footer.

**Reviewer focus:** Export download with filters; place filter only when a row was chosen; keyboard/mouse combobox paths; map hover/click popups + report link. No automated coverage added.

**Out of scope / follow-ups (not on this branch)**
- Stimulus specs for place autocomplete or export
- Shared JS module for focus ring (ERB helper + templates preferred)
- `tooltip_controller.js` still sets one `className` string for floating tips (acceptable one-off)

---

## Dead JSON API + serializer cleanup

**Summary:** Removed unused `PublicWaterSystemsController` (`index`/`show`), all three PWS serializers, and associated specs/views. Routes now expose only the live nested endpoints (`stats`, `export`, `histogram`, `report`). Documentation updated to reflect Hotwire as the decided architecture.

**Removed**
- `app/controllers/public_water_systems_controller.rb`
- `app/serializers/public_water_system_{,detail_,table_}serializer.rb`
- `app/views/public_water_systems/show.html.erb`
- `spec/requests/public_water_systems_spec.rb`, `spec/serializers/*`

**Docs updated**
- `docs/FRONTEND_DECISION.md` — rewritten as decision record (what/why/done), not an implementation guide
- `docs/API.md`, `docs/ARCHITECTURE.md`, `docs/DISCOVERY.md`, `ROADMAP.md`, `docs/TRANSITION.md`

---

## Sidebar — Explore the Table nav item

**Status:** In progress on this branch (uncommitted).

**Summary:** Adds **Explore the Table** to the desktop sidebar (`#sidebar-nav`), directly below **Explore the Map**. Reuses existing `nav#show` / `section: "table"` wiring and `table.svg` via `UI::NavItemComponent`. Table view remains desktop-only (`#container-table` is `max-md:!hidden`); the mobile menu overlay omits this item so users are not offered a control with no visible result on small screens.

**Added**
- `app/views/home/_core_section_nav.html.erb` — shared section nav items (Map, optional Table, Datasets, Documentation, Downloads) for sidebar + mobile menu

**Changed**
- `app/views/home/_sidebar.html.erb` — renders `_core_section_nav` (includes table)
- `app/views/home/index.html.erb` — mobile menu renders `_core_section_nav` with `include_table: false`
- `app/javascript/controllers/nav_controller.js` — sync `aria-current="page"` on all `nav#show` section buttons (sidebar, mobile menu, map/table FABs), not sidebar-only

**Removed / not used**
- Duplicated inline nav item markup in `_sidebar.html.erb` and mobile menu

**How to test**

Manual (`PORT=3001 bin/dev` if the main worktree uses 3000):

*Desktop sidebar (`sm+`)*
1. Sidebar → **Explore the Table** (below **Explore the Map**) → table panel opens over map; filter bar stays visible
2. Bottom-right Map/Table FABs stay in sync (active state matches sidebar)
3. Tab to sidebar table button → Enter/Space activates; focus ring visible
4. Collapsed sidebar → table icon-only button still works (`aria-label` on button)

*Mobile menu (`< sm`)*
1. Hamburger → menu lists Map, Datasets, Documentation, Downloads — **no** Explore the Table entry
2. Section switches still close the overlay

**Notes**
- **Pattern:** Same `UI::NavItemComponent` as other section buttons (`<button>`, `data-section`, `focus_ring_classes`, visible label + `aria-hidden` icon).
- **DRY:** `_core_section_nav` keeps sidebar and mobile core nav in sync; mobile-only footer links (Github, Feedback, Contact) stay inline in `index.html.erb`.
- **A11y fix:** `aria-current` now updates on map/table FAB toggles too (previously only sidebar buttons).
- No new automated specs — manual only.
- **Out of scope:** Enabling table view on mobile (`max-md:!hidden` on `#container-table` unchanged).

**PR notes** (sidebar table slice — paste/adapt for multi-domain PR)

Restores table discovery in the left nav (legacy PHP had a Table item) using the existing table section switcher — no new routes or Stimulus actions. Shared partial reduces drift between desktop sidebar and mobile menu; table is omitted from mobile because the table panel is desktop-only.

**Reviewer focus:** Sidebar table button on `sm+`; FAB/sidebar active-state sync; mobile menu does not show table; keyboard activation.

---

## Map — initial viewport & mobile chrome

**Status:** Done on this branch (manual QA complete). Independent of other slices; safe to review separately.

**Summary:** Fix initial map framing when the floating sidebar covers the left edge on desktop. Mobile gets a dedicated center/zoom (legacy-style national view) instead of `fitBounds`, which fought portrait aspect ratio. Hide desktop-only map controls on phones (zoom +/−, region fly-to shortcuts).

**Changed**
- `app/javascript/controllers/map_controller.js` — `#fitDefaultView`, `#desktopMapLayout`, `#desktopPadding`, `#sidebarLeftInset`; layout-specific `minZoom`; `zoom48()` delegates to `#fitDefaultView`
- `app/views/home/index.html.erb` — `#container-region-nav` adds `hidden sm:block`
- `app/assets/tailwind/application.css` — hide `.mapboxgl-ctrl-group` below 640px (mobile-first: hidden by default, `min-width: 640px` shows)
- `docs/MAPPING.md` — **Initial Viewport** section; `zoom48()` row updated

**Removed / not used**
- Uniform `fitBounds` + `padding: 20` for all viewports
- `matchMedia` breakpoint checks for layout
- Per-corner overlay measurement for `fitBounds` padding (Mapbox applies padding per full edge, not per control)

**How to test**

Manual (`PORT=3001 bin/dev` if the main worktree uses 3000):

*Desktop (`sm+`, sidebar open)*
1. Hard-refresh `/` → continental US visible; west and east coasts clear of sidebar
2. Collapse sidebar → **48** → same national framing with less left inset
3. **48** / AK / HI shortcuts still work; zoom +/− visible top-left

*Mobile (`< 640px` width)*
1. Hard-refresh → national view at zoom 2 (`mapDebug.getZoom()` on localhost)
2. No zoom +/− buttons; no 48/AK/HI region column (pinch-to-zoom OK)
3. Tweak `MOBILE_DEFAULT_ZOOM` in `map_controller.js` → visible after refresh (requires `MOBILE_MIN_ZOOM` ≤ zoom)

**Notes**
- **Layout detection:** `#container-sidebar` `getBoundingClientRect().width > 0` mirrors `hidden sm:flex` in markup (`docs/TAILWINDS_CSS_GUIDE.md` — DOM truth, not JS breakpoints).
- **Desktop vs mobile camera:** Desktop `fitBounds` + sidebar left padding; mobile `center`/`zoom` (not different geographic bounds — different framing strategy).
- **`minZoom` trap:** Global `minZoom: 3` silently clamped mobile zoom; split into `DESKTOP_MIN_ZOOM` (3) and `MOBILE_MIN_ZOOM` (2).
- **Initial load** uses `#fitDefaultView({ duration: 0 })`; **48** button uses animated default.
- Geolocation auto-center deferred (out of scope).
- No new automated specs — manual only.

**PR notes** (map viewport slice — paste/adapt for multi-domain PR)

Corrects default map framing now that the sidebar floats over the canvas on desktop. Uses measured sidebar inset for `fitBounds` left padding only (not corner controls — full-edge padding was zooming out/shifting center incorrectly). Mobile uses explicit center/zoom with a lower `minZoom` so tuning constants actually apply. Hides Mapbox zoom buttons and region shortcuts on small screens per mobile-first visibility patterns.

**Reviewer focus:** Desktop west coast visible beside open sidebar; mobile national zoom; hidden zoom/region controls on phone; **48** reset on both layouts.

**Out of scope / follow-ups (not on this branch)**
- Refit on sidebar toggle or orientation change
- Hide Mapbox geocoder on mobile (filter panel has place search)
- Geolocation “near me” initial view

---
