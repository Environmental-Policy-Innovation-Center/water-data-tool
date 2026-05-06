# Frontend Architecture Plan
**Water Tool · Rails 8 Hotwire**
_April 2026_

---

## Architecture Decision

> **Stay on Hotwire. Modernize with ViewComponent + Tailwind.**
> No React. No Node build pipeline. Convention-first Rails.

| | |
|---|---|
| **JS approach** | Hotwire + Stimulus |
| **Components** | ViewComponent + Lookbook |
| **Styling** | Tailwind CSS v4 |

---

## 1. Architecture Overview

The primary UI is a single-route experience on HomeController#index. The map, filters, table, and stats bar all live on this page. Section switching is handled client-side by nav_controller toggling CSS visibility — no navigations occur within the main UI. The application has additional routes (dataset downloads, etc.) which Turbo Drive handles normally, but these are not part of the interactive UI layer.

### 1.1 Layer Model

| Layer | Technology | Responsibility |
|---|---|---|
| HTML structure | Rails ERB + ViewComponent | Server renders all HTML. Components encapsulate repeating UI patterns with clean Ruby interfaces. |
| Styling | Tailwind CSS v4 | Utility classes on elements. No separate CSS files per component. `water_tool.css` deprecated gradually. |
| Behavior | Stimulus controllers | DOM interactions, event handling, third-party JS integration. No application state in Stimulus. |
| Map | Mapbox GL JS (CDN) | Fully client-side. Framework-neutral. Always managed by `map_controller.js`. |

### 1.2 Data & Event Flow

When a filter changes, the following sequence occurs:

1. User changes a filter checkbox (server-rendered HTML)
2. User clicks Apply → `filter_controller` reads DOM, writes to `FilterState` singleton, dispatches `filters:changed`
3. `map_controller` hears `filters:changed` → fetches `GET /map?params` → Rails returns `{ pwsids: [...] }` JSON
4. `map_controller` calls `this.map.setFilter(...)` → Mapbox re-renders map tiles client-side (no HTML involved)
5. `filter_controller` sets `stats-bar` Turbo Frame `src` → Rails renders `stats/show.html.erb` fragment → Turbo swaps HTML
6. If table is visible: `table_controller` reloads Turbo Frame to `/table?params`

### 1.3 File Structure (Target State)

```
app/
  assets/
    stylesheets/
      water_tool.css              ← deprecated, removed section by section
      tailwind/application.css    ← @import 'tailwindcss' only
  components/                     ← ViewComponent root (auto-loaded)
    ui/
      button_component.rb
      button_component.html.erb
      card_component.rb
      card_component.html.erb
      dataset_card_component.rb
      detail_section_component.rb
    previews/                     ← Lookbook previews
      ui/
        button_component_preview.rb
  javascript/
    controllers/
      map_controller.js           ← owns Mapbox instance
      filter_controller.js        ← refactored: declarative config
      nav_controller.js           ← mobile nav fix applied
      table_controller.js         ← removed after Tier 2
      datasets_controller.js
      slider_controller.js        ← implemented in Tier 5
    filter_state.js               ← singleton, unchanged
  views/
    layouts/application.html.erb  ← tailwind link tag added
    home/
      index.html.erb
      _sidebar.html.erb
      _filter_menus.html.erb
      _table.html.erb             ← replaces DataTables (Tier 2)
      _datasets.html.erb          ← data-driven loop (Tier 3)
    public_water_systems/
      sections/                   ← converted to DetailSectionComponent
```

---

## 2. ViewComponent Design System

### 2.1 Philosophy

ViewComponent replaces the role that CSS class abstractions used to play. Instead of `.card` and `.btn-primary` in a stylesheet, you have `CardComponent` and `ButtonComponent` in Ruby. The component is the reusable unit — it owns its markup and its Tailwind classes.

Lookbook provides a browsable component catalog (like Storybook, but Rails-native). Designers can reference it alongside Figma. Developers see live previews with controls.

### 2.2 Component Location & Namespace

All components live in `app/components/ui/` and use the `UI::` namespace. This is deliberate: the `UI::` prefix is the future gem name. When a second app needs these components, the extraction path is:

1. Copy `app/components/ui/` into a new gem structure
2. Point the consuming app's `Gemfile` at the gem
3. Add the gem's path to Tailwind content scanning
4. Components require zero changes — interfaces are already clean

> **Do not extract to a gem until a second consumer exists.** Building gem infrastructure without a real second consumer adds complexity with no benefit. Design for extraction, but don't do it yet.

### 2.3 Component Rules

These rules must be followed for every component. They ensure future gem extraction is painless and components remain reusable.

| Rule | Description |
|---|---|
| **R-01** | **No ActiveRecord objects as arguments.** Pass plain data (strings, integers, arrays, hashes). Never pass a model instance. Extract fields in the view or controller first. |
| **R-02** | **No route helpers inside components.** Pass URLs as string arguments. Components must not know about application routing. |
| **R-03** | **Tailwind only — no `water_tool.css` class references.** The legacy CSS file will not travel with a future gem extraction. |
| **R-04** | **Every component gets a Lookbook preview.** A component without a preview is not complete. Show at least the default state and any meaningful variants. |
| **R-05** | **`UI::` namespace for all design system components.** Example: `UI::ButtonComponent`, `UI::CardComponent`. Page-specific: `Home::SidebarComponent`. Never put a design system component in the root namespace. |
| **R-06** | **Components are data-in, HTML-out — no side effects.** No fetching, no events, no global state mutations in `initialize` or `call`. |

---

## 3. Tailwind CSS Migration

### 3.1 Current State

Tailwind CSS v4 (`tailwindcss-rails 4.4.0`) is installed but was not served to the browser until Tier 1. The layout previously only included `water_tool.css`. Zero Tailwind utility classes appeared in any template. Fix: add `stylesheet_link_tag "tailwind"` to `application.html.erb`.

### 3.2 Migration Strategy

Do not convert `water_tool.css` to Tailwind all at once. Convert incrementally as components are extracted:

- When a UI element is extracted into a ViewComponent, rewrite its styles as Tailwind classes on the component template
- Remove the corresponding CSS block from `water_tool.css`
- Track removed line ranges in a comment at the top of `water_tool.css`
- Target: `water_tool.css` at zero lines when all components are extracted

**Dead code to delete immediately (no active references):**
- Lines 29–56: Tippy.js styles (Tippy is not loaded)
- Lines 827–940: Slider/histogram CSS (slider_controller now renders SVG — these legacy CSS rules do not apply to the current implementation)
- Lines 1716–1759: `.filter-list-container` (always `display:none`, never shown)
- Lines 1840–1895: Choropleth legend CSS (feature not built)

### 3.3 Tailwind Configuration

Tailwind v4 uses CSS-based configuration. The source file is `app/assets/tailwind/application.css`. Design tokens from Figma go here:

```css
@import "tailwindcss";

@theme {
  --color-brand-primary: #YOUR_COLOR;
  --color-brand-secondary: #YOUR_COLOR;
  --font-sans: 'Public Sans', sans-serif;
}
```

---

## 4. Icon System

### 4.1 Current State

All ~50 icons are PNG files in `app/assets/images/`, used as CSS `background-image` references or `image_tag` helpers. Many come in dark/white pairs (e.g. `icon-explore-dark.png` / `icon-explore-white.png`). No SVG system exists.
- Update: many SVG versions of the existing assets have been downloaded in .svg form and can be found in the `app/assets/dwet_design_system_svgs` directory. Flag any missing SVG files that we need to find and download.

### 4.2 Inline SVG via Helper — Implemented

The `icon()` helper is live in `app/helpers/ApplicationHelper`. Current implementation:

```ruby
# app/helpers/application_helper.rb
ICON_CACHE = Hash.new do |h, k|
  h[k] = begin
    File.read(Rails.root.join("app/assets/images/icons/#{k}.svg"))
  rescue Errno::ENOENT
    ""
  end
end

def icon(name, classes: nil, aria_hidden: true)
  safe_name = name.to_s.gsub(/[^a-z0-9\-_]/, "")   # path sanitization
  svg = ICON_CACHE[safe_name]
  return "".html_safe if svg.empty?
  attrs = []
  attrs << "class=\"#{ERB::Util.html_escape(classes)}\"" if classes
  attrs << 'aria-hidden="true"' if aria_hidden
  replacement = attrs.any? ? "<svg #{attrs.join(" ")}" : "<svg"
  svg.sub("<svg", replacement).html_safe
end
```

```erb
<%# In a template or component %>
<%= icon('external-link', classes: 'inline w-4 h-4') %>
```

Key behaviors:
- `ICON_CACHE` caches reads per process — no repeated disk I/O per request
- Returns `"".html_safe` (safe empty string) for missing files — callers never see broken images
- `aria-hidden: true` by default — pass `aria_hidden: false` for icons that need announcement
- `classes` is HTML-escaped before injection — safe against XSS from dynamic class strings
- Icon names are sanitized to `[a-z0-9\-_]` — prevents path traversal
- Filenames follow Figma names (kebab-case, no `icon-` prefix). Example: `icon('external-link')` not `icon('icon-ext-link')`

### 4.3 What to Get from Figma

- All ~50 icons as SVG — right-click frame → Export → SVG → save to `app/assets/images/icons/`
- Ensure SVG paths use `currentColor` instead of hardcoded hex
- Logo variants (dark/light/monochrome) as SVG
- Design tokens: colors, spacing, typography, border radius, shadow values

STATUS UPDATE: 
  - ~44 SVG files were downloaded from the 'Icons & Logos' section of the design system in Figma.
  These have been saves in the `app/assets/dwet_design_system_svgs` directory
    - These were downloaded, presumably using the `RGB` selection for 'Colors', and `sRGB (same as file)` for the 'Color profile' option
    - `currentColor` was not an option
  - Presumably we are missing some navigation arrows, when comparing to the current `/images/icons` dir.

Standard editor access is sufficient. Dev Mode is optional but useful for exact spacing values.

---

## 5. Implementation Plan

### Tier 1 — Fix Broken / Missing Things ✅

| Task | Status | Description | Test |
|---|---|---|---|
| **T1-A** | ✅ Done | **Wire Tailwind into the layout.** Add `stylesheet_link_tag "tailwind"` to `application.html.erb`. | Tailwind stylesheet appears in Network tab on page load. |
| **T1-B** | ✅ Done | **Fix mobile navigation.** Add `data-action="click->nav#show"` and `data-section="[section]"` to all links in `#container-mobile-menu`. Mirror `_sidebar.html.erb` exactly. Also: extract `#closeMobileMenu()` helper in `nav_controller.js` so overlay closes on section switch. Also: add `left: 0` mobile override in `water_tool.css` so Datasets/Downloads content is not hidden behind the sidebar offset. | On mobile viewport: tap hamburger → menu opens. Tap any nav link → correct section appears, menu closes. Tap hamburger again → menu closes without navigating. |
| **T1-C** | ✅ Done | **Move stats-bar reload to `filter_controller`.** Remove `#reloadStatsFrame()` from `table_controller.js`. Add it to `filter_controller`'s `apply()` and `#restoreFromUrl()`. Stats bar reloads on any filter change, regardless of which section is visible. | Apply a filter on the Map view → stats bar updates. Switch to Table view → stats bar is already current. Reload page with filter params in URL → stats bar reflects restored filters. |
| **T1-D** | ✅ Done | **Delete dead CSS.** Removed Tippy.js, slider/histogram, `#filter-list-container`, choropleth legend from `water_tool.css`. ~390 lines removed. | No visible regressions in map, table, filter bar, or report overlay. |

### Tier 2 — Replace DataTables with Turbo Frame Table ✅

| Task | Status | Description | Test |
|---|---|---|---|
| **T2-A** | ✅ Done | **Create `_table.html.erb` partial.** Server-rendered HTML table wrapped in `<turbo-frame id="data-table">`. Column definitions move from 69 DataTables JS defs to ERB. Tailwind classes for styling. `table-fixed` layout with explicit `w-*` widths prevents column shift on filter. Boolean columns render "Yes"/"No". All columns have sort links with ↑/↓ indicators. | Rendered in browser: correct columns, Tailwind styling, sort links work, Yes/No booleans display, horizontal scroll position stable after filter apply. |
| **T2-B** | ✅ Done | **Add `HomeController#table` action.** Renders `_table.html.erb` as a Turbo Frame response. Accepts filter params. Reuses existing `Filterable` concern. `SORTABLE_COLUMNS` allowlist guards `ORDER BY`. | Visited `/table?gw_sw_code=Groundwater` directly — returns Turbo Frame response with filtered rows. 12 request specs pass (`bundle exec rspec spec/requests/home_spec.rb`). |
| **T2-C** | ✅ Done | **Update `filter_controller` to reload Turbo Frame.** On `filters:changed`, calls `Turbo.visit("/table?[params]", { frame: "data-table" })`. Guards on `#tableLoaded` flag so no background requests fire until user opens Table view. | Applied filters while in Table view — frame reloads with filtered data. Switched from Map view to Table view after changing filters — table reflects current filters. |
| **T2-D** | ✅ Done | **Remove DataTables, jQuery, `table_controller`.** Remove CDN script tags from `application.html.erb`. Delete `table_controller.js`. Remove DataTables CSS overrides from `water_tool.css`. | Confirmed in browser console: `typeof window.DataTable === "undefined"`. No requests to `datatables.net` or `jquery` CDNs in Network tab on a fresh private window load. |

### Tier 3 — Introduce ViewComponent + Tailwind Components ✅

| Task | Status | Description | Test |
|---|---|---|
| **T3-A** | ✅ Done | **Install `view_component` (4.8.0) and `lookbook` (2.3.14) gems.** Lookbook mounted at `/lookbook` in development only. `UI::` acronym inflection added to `config/initializers/inflections.rb` so Zeitwerk resolves the namespace. `spec/support/view_component.rb` wires `ViewComponent::TestHelpers` into RSpec. |
| **T3-B** | ✅ Done | **Extract `UI::DetailSectionComponent`.** Accepts `title:`, `rows: [{label:, value:}]`, `data_available: true`. Violations section uses content-block form (its table has multi-column headers that don't fit the row model). Trends flag spans encoded as html_safe values in the row's value field. All 8 partials replaced. |
| **T3-C** | ✅ Done | **Extract `UI::DatasetCardComponent` + make `_datasets.html.erb` data-driven.** All 27 datasets extracted to `config/datasets.yml`. `HomeHelper::DATASETS` constant loads YAML once at boot (not per-request). `HomeHelper#datasets` returns the constant. The 671-line hardcoded partial is now a 5-line loop. Dataset count in the header is dynamic. |
| **T3-D** | ✅ Done | **SVG icon system wired up.** `icon()` helper added to `ApplicationHelper` — inlines SVG, adds `aria-hidden="true"` by default. 30 SVGs copied to `app/assets/images/icons/` using Figma SVG names (not legacy `icon-*.png` names). All 10 `image_tag` icon references in views replaced. **7 SVGs still missing — see below.** CSS `background-image` PNG references in `water_tool.css` are not yet replaced (deferred until surrounding HTML is converted to components). |
| **T3-E** | ✅ Done | **Tailwind `@theme` tokens configured.** Confirmed tokens added: `--font-sans`, `--color-brand-primary` (#1054A8), `--color-brand-accent` (#4EA324), `--color-brand-dark` (#13171F), neutral scale. **Tokens requiring Figma confirmation are marked with comments in the file** — secondary color, hover states, border-radius values, shadows. |

#### Tier 3 — Implementation notes for future agents

**Project uses RSpec, not Minitest.** Component specs live in `spec/components/ui/` (not `test/`). The `spec/support/view_component.rb` file includes `ViewComponent::TestHelpers`. Capybara is not installed — use `Nokogiri::HTML.parse(rendered_content)` for structural assertions, `rendered_content` with `include` for text checks.

**`UI::` namespace requires an inflection.** Without it Zeitwerk maps `app/components/ui/` to `Ui::` (wrong). The fix is in `config/initializers/inflections.rb` and is already in place.

**`icon()` helper behavior:** Returns `"".html_safe` (empty string) if the SVG file doesn't exist — safe to call for icons that haven't been migrated yet. `aria-hidden: true` is the default; pass `aria_hidden: false` for decorative icons that need to be announced. SVG content is cached in `ICON_CACHE` (process-level Hash) — no per-request disk reads.

**SVG icon status — see [`docs/frontend_refactor/SVG_ICONS.md`](SVG_ICONS.md)** for:
- Which SVG files are still needed to complete the PNG migration
- The ideal end-state file list (full `currentColor` set, ~28 files)
- Which current dark/white pairs can be consolidated once replacements are in place

All 30 existing SVGs in `app/assets/images/icons/` have been updated to use `fill="currentColor"`.

#### Tier 3 — Definition of done for every component

Every component task is not complete until all three of the following exist:

| Requirement | Detail |
|---|---|
| **RSpec spec** | `spec/components/ui/[name]_component_spec.rb` with `type: :component`. Must cover: default render, meaningful variants, nil/empty edge cases. Use `Nokogiri::HTML.parse(rendered_content)` for structural assertions. |
| **Lookbook preview** | `app/components/previews/ui/[name]_component_preview.rb` with at least a default preview and one variant preview. |
| **No ActiveRecord in spec** | Tests pass plain data only (strings, arrays, hashes). If you load a fixture or factory, the component violates R-01. |

Example spec structure:
```ruby
# spec/components/ui/detail_section_component_spec.rb
RSpec.describe UI::DetailSectionComponent, type: :component do
  def html = Nokogiri::HTML.parse(rendered_content)

  it "renders the title" do
    render_inline described_class.new(title: "Water Source", rows: [{label: "Type", value: "Groundwater"}])
    expect(html.css("h3").text).to include("Water Source")
  end

  it "renders data not available when data_available is false" do
    render_inline described_class.new(title: "Trends", data_available: false)
    expect(rendered_content).to include("Data not available")
    expect(html.css("table")).to be_empty
  end
end
```

#### Tier 3 — A11y + Code Quality Pass (done after initial Tier 3)

A follow-up pass was applied to all Tier 3 output. The following were fixed — a new agent does not need to redo these:

**Accessibility:**
- Filter/sort panel toggle links (`<a href="javascript:void(0)">`) converted to `<button type="button">` with `aria-expanded` and `aria-controls`
- Filter frequency buttons and sort buttons: `aria-pressed` state managed by `datasets_controller.js`
- Violations table: `<thead><th scope="col">` added; visual column labels div marked `aria-hidden="true"`
- Sidebar: `<div>` → `<aside>`, `<div class="container-sidebar-nav">` → `<nav>`, toggle button has `aria-label`, nav links have `aria-current="page"` managed by `nav_controller.js`
- Logo images have `alt` text; decorative logo stacked text marked `aria-hidden="true"` in report header
- Reset sort `<a>` converted to `<button type="button">`

**Code quality / correctness:**
- `trend_value` bug fixed: 0% now renders neutral gray span, not a misleading red down-arrow
- `datasets_controller.js`: `togglePanel` mirror duplication collapsed to symmetric 8-line implementation; `#clearButtonGroup` private method extracted from 4 callers
- `dataset_card_controller.js`: `expand()` no longer duplicates `_updateToggleVisibility` state (delegates to `_scheduleUpdate`); window resize listener removed (ResizeObserver covers viewport reflows); double `requestAnimationFrame` collapsed to single; `_destroyed` guard prevents `fonts.ready` callback firing after disconnect
- `detail_section_component.html.erb`: `unless/else + if/else` nesting flattened to `if/elsif/else`
- `icon()` helper: `ICON_CACHE` constant added (no per-request disk reads); `classes` HTML-escaped via `ERB::Util.html_escape`; path sanitized against traversal
- `DATASETS` constant: YAML parsed once at boot, returned by `HomeHelper#datasets` — no per-request I/O

#### Tier 3 — Manual test checklist

Run `bin/dev` and verify the following before marking Tier 3 closed:

**T3-A — ViewComponent / Lookbook**
- [x] Visit `/lookbook` in browser → Lookbook UI loads, no errors
- [x] `UI::DetailSectionComponent` and `UI::DatasetCardComponent` previews appear in the left-hand catalog

**T3-B — DetailSectionComponent**
- [x] Click a map marker → report overlay opens → all 8 sections render with titles and data rows
- [ ] For a PWS that has no demographic data → Demographics section shows "Data not available" [Cannot find a PWS without demographic data]
- [x] Violations section renders with 5-Year / 10-Year column headers and a Total row
- [x] Trends section shows flag spans (e.g. "▲" or "▼" badge) next to values where applicable

**T3-C — DatasetCardComponent / datasets loop**
- [x] Navigate to Datasets section → all 27 cards render
- [x] Header reads "27 datasets available"
- [x] Filter by source (e.g. EPA) → only EPA cards remain visible
- [x] Filter by frequency (Annually) → correct subset shown
- [x] Sort by Newest / Oldest → cards reorder correctly
- [x] "Show all" resets filters and count
- [x] Each card shows title, description, source link, last-updated date (M/D/YYYY format), update frequency, and caveats list

**T3-D — Icon system**
- [x] Mobile hamburger icon renders as inline SVG (not an `<img>` tag) — inspect element to confirm
- [x] Tapping hamburger opens mobile menu; X (close icon) is shown and works
    [No close Icon]
- [ ] Map/Table toggle icons appear correctly (map-white/map-dark, table-dark/table-white)
    [I do not see these on mobile, where would I expect to find them?]
- [ ] Export button shows downloads icon
- [ ] Report close button (X) renders and closes the overlay
- [ ] Sidebar: Documentation, Github, Feedback links show external-link SVG icon; Contact shows email icon
    [Side bar does not appear to show on mobile]
- [ ] Print button on report overlay still renders (still uses `icon-print.png` PNG — confirm no broken image)

**T3-E — Tailwind tokens**
- [x] Open browser DevTools → computed styles on a Tailwind-styled element → confirm `font-family` includes `Public Sans`
- [x] `bg-brand-primary` class in any template renders as `#1054A8` blue

---

### Tier 4 — Refactor `filter_controller.js` ✅

| Task | Status | Description | Test |
|---|---|---|---|
| **T4-A** | ✅ Done | **Define declarative `FILTERS` config array.** Each entry defines `{ type, group, param, ...type-specific }`. Types: `radio`, `bool`, `group`, `select`, `pop_cat`, `place`. `GROUP_KEYS` derived at module load via `FILTERS.reduce()`. | FILTERS drives both collect and restore — adding a new filter is one config entry. |
| **T4-B** | ✅ Done | **Rewrite `#collectFilters()` as a loop.** Replaced ~100-line imperative DOM-reading with a `for` loop over `FILTERS` with a `switch` on type. | Each filter type reads correctly; URL params match expected values after Apply. |
| **T4-C** | ✅ Done | **Rewrite `#restoreDomState()` as a loop.** Replaced ~100-line imperative DOM-writing with a symmetric loop. URL restore on page reload correctly restores all filter types. | Copy URL with params → open new tab → all filter DOM state restores correctly. |
| **T4-D** | ✅ Done | **Extract sub-controllers.** `filter_menu_controller.js` (open/close/dismiss, outside-click, `filter:close-all` listener). `filter_layout_controller.js` (ResizeObserver, breakpoint-crossing guard, DOM reparenting into More menu). `filter_controller.js` reduced to state collect/restore/dispatch only. | Dropdown open/close, outside-click dismiss, responsive tab collapse all work independently. |

#### Tier 4 — Fixes applied during testing

| Fix | File(s) | Notes |
|---|---|---|
| `filter:close-all` moved inside breakpoint-crossing branch | `filter_layout_controller.js` | Was firing on every resize pixel; now only fires when a breakpoint actually crosses |
| `#setBadge(badge, count)` helper extracted | `filter_controller.js` | Eliminated duplicated badge DOM write in `#updateBadges()` |
| `countKeys` predicate simplified | `filter_controller.js` | `val !== undefined && val !== null && val !== ""` → `val != null && val !== ""` |
| Source (group 1) added to `RESPONSIVE_FILTERS` at 580px | `filter_layout_controller.js` | Source now collapses into More at narrow widths; More tab persists on its own |
| Datasets mobile: sticky header → `md:sticky` | `_datasets.html.erb` | Sticky header took up too much vertical space on mobile, appearing to block scrolling |
| Datasets mobile: padding `px-9` → `px-4 md:px-9` | `_datasets.html.erb` | Tighter horizontal padding on mobile |
| Datasets mobile: description text hidden on mobile | `_datasets.html.erb` | "EPIC wants to know…" copy hidden on mobile to reduce header height |
| Datasets mobile: data source `<select>` overflow fixed | `_datasets.html.erb` | `inline-block` wrapper → `block w-full`; `<select>` gets `w-full` |

#### Tier 4 — Manual test checklist

**T4-A/B/C — Filter collect and restore**
- [x] Apply each filter type (radio, bool, group, select, pop_cat) → correct URL params appear after Apply
- [x] Copy URL with params → open new tab → all filter DOM state restores (radio checked, checkboxes, pop-size buttons active)
- [x] Reset in a menu → filter clears, URL param removed
- [x] Reset All → all menus reset, clean URL

**T4-D — FilterMenuController**
- [x] Click filter tab → dropdown appears below button
- [x] Click same tab again → closes
- [x] Click a different tab → previous closes, new one opens (only one at a time)
- [x] Click outside any open menu → closes
- [x] Click inside open menu → stays open
- [x] Apply → dropdown closes

**T4-D — FilterLayoutController** *(tested at zoom 100%, Chrome)*
> Note: breakpoints are **container widths** (not window widths). The sidebar takes ~250px, so observed window widths are ~250px larger than the `RESPONSIVE_FILTERS` values.
- [x] Wide viewport: all 5 filter tabs visible
- [x] Narrow: Population collapses into More (at container ~1190px / window ~1440px)
- [x] Narrow further: Compliance, Boundaries, Attributes collapse in sequence
- [x] Narrow further: Source collapses into More (at container ~580px)
- [x] Widen back → tabs re-appear; More no longer contains them
- [x] Resize with a dropdown open → dropdown closes automatically

**Badge counts**
- [x] No filters → all badge circles hidden
- [x] Apply Source filter → badge count appears on Source tab
- [x] Collapse Source into More → badge count moves to More tab
- [x] Combine More-menu filters with collapsed Source → More badge shows combined total

**Stats bar + table frame**
- [x] Apply any filter → stats bar updates
- [x] Filter while in Table view → table reloads
- [x] Switch views → no stale data, no double-reload

### Tier 5 — Implement Histogram Slider ✅

| Task | Status | Description | Test |
|---|---|---|---|
| **T5-A** | ✅ Done | **`slider_controller.js` + histogram API.** Dual-handle range slider with inline SVG histogram. No chart library — bars are `<rect>` elements drawn by the controller. PostgreSQL `width_bucket` endpoint at `GET /public_water_systems/histogram?field=`. Fetch on `connect()`, cached in module-level `Map`. Commit-on-pointerup pattern — filter_controller reads hidden inputs on Apply. `PublicWaterSystems::HistogramsController` with `ALLOWED_FIELDS` allowlist. `ViolationsSummary.histogram_bins(field, num_bins: 50)` model method. | Histograms render with real data: `paperwork_violations_5yr` shows 1–1,070 range. |
| **T5-B** | ✅ Done | **Chart library decision: none.** Mocks show a minimal bar chart achievable with inline SVG. No CDN dependency. | No Highcharts/Chart.js requests in Network tab. |
| **T5-C** | ✅ Done | **`range` type added to `FILTERS` config.** `collectFilters()` sends `_min`/`_max` params when parent is checked and value differs from full-domain default. `restoreDomState()` sets hidden inputs; slider reads them on `connect()`. | Apply with slider range → correct `_min`/`_max` params in URL. |
| **T5-D** | ✅ Done | **Slider markup in `_filter_menus.html.erb`.** Hidden panel `<div>` inside each paperwork `<li>`, revealed by `toggleSubcat`. Carries `data-controller="slider"` with `field` and `url` values. | Checking "Non-health violations" parent reveals histogram panel. |

#### Tier 5 — Manual test checklist

- [ ] Checking parent reveals histogram panel; histogram loads and renders
- [ ] Dragging min handle grays bars to the left; value tooltip shows current value
- [ ] Dragging max handle grays bars to the right
- [ ] Releasing handle commits values to hidden inputs
- [ ] Apply sends `paperwork_violations_5yr_min=N&paperwork_violations_5yr_max=M` in URL
- [ ] Unchecking parent hides histogram, clears min/max params on Apply
- [ ] Reset restores parent to unchecked, histogram hidden, params cleared
- [ ] URL restore sets slider positions correctly
- [ ] Edge case: `domain_max === 1` renders flat line
- [ ] Histogram data is cached — reopening menu does not re-fetch
- [ ] Histogram endpoint returns 400 for unknown field names (security)

#### Tier 5 — Follow-up work

**Per-sub-category histograms** (Phase 3 in `HISTORGRAMS.md`): Done. Health subcat params switched from boolean to range style (`groundwater_rule_5yr_min=N&groundwater_rule_5yr_max=M`). `filterable.rb` OR-range Arel logic added. `ALLOWED_FIELDS` expanded to 22. All 20 subcat `<li>` items render the `_slider_panel.html.erb` partial. See `HISTORGRAMS.md` Phase 3 section for full detail.

**Visual styling**: The current histogram renders correctly but uses minimal default styling. A design pass is needed before marking Tier 5 fully closed.

**Manual UI testing**: The T5 test checklist above and the Phase 3 checklist in `HISTORGRAMS.md` are still pending manual browser verification.

---

## 6. Agent Rules Reference

All rules to be followed by AI agents and developers working in this codebase.

| ID | Rule | Detail |
|---|---|---|
| R-01 | No models in components | Pass plain data — never ActiveRecord objects |
| R-02 | No route helpers in components | Pass URLs as string arguments to initializer |
| R-03 | Tailwind only in components | Never reference `water_tool.css` classes inside any component |
| R-04 | Lookbook preview required | Every component needs a preview before it is considered complete |
| R-05 | `UI::` namespace always | Design system: `UI::ButtonComponent`. Page-specific: `Home::X` |
| R-06 | Components are pure renderers | No fetching, no events, no side effects in `initialize` or `call` |
| R-07 | One stats-bar reload location | Only `filter_controller` fires the stats-bar Turbo Frame reload |
| R-08 | Mobile nav mirrors desktop | Any link in `_sidebar.html.erb` must have an equivalent in `#container-mobile-menu` with identical `data-action` wiring |
| R-09 | No new jQuery usage | jQuery exists only for DataTables. Do not use `$` or `jQuery()` in any new code. Removed in Tier 2. |
| R-10 | Icons via helper, not `image_tag` | New icon usage: `<%= icon('name', classes: '...') %>`. Never add new `image_tag` icon references. |
| R-11 | FilterState is the source of truth | Filter params flow through `filter_state.js` singleton. Controllers read FilterState, not each other. |
| R-12 | Slider fires on release, not on drag | `slider_controller` dispatches `filters:changed` on `mouseup`/`pointerup` only — never on `input` event during drag. |

---

## 7. Figma Handoff Checklist

Standard editor access is sufficient for all initial work. Dev Mode is optional.

**Immediate exports needed (before Tier 3):**
- All ~50 icons as SVG → `app/assets/images/icons/`
- Logo variants as SVG
- Any brand marks as SVG

**Design token values to read from Figma inspect panel:**
- Brand colors (primary, secondary, accent) — exact hex
- Neutral gray scale (50–900 if defined)
- Typography: font family, sizes, weights
- Spacing scale and base unit
- Border radius values (cards, buttons, inputs)
- Shadow values (modals, dropdowns, elevated surfaces)

**Reference documents:**
- `docs/arch_01_layer_structure.png` — layer structure diagram
- `docs/arch_02_filter_event_flow.png` — filter event flow diagram
- `docs/FE_Architecture_Decision_Rationale.md` — why Hotwire, why not React

