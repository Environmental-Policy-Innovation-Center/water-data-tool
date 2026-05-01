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
- Lines 827–940: Slider/histogram CSS (slider_controller is a stub)
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

### 4.2 Target: Inline SVG via Helper

Replace PNGs with SVGs exported from Figma. The target pattern:

```ruby
# app/helpers/application_helper.rb
def icon(name, classes: nil)
  file = Rails.root.join("app/assets/images/icons/#{name}.svg")
  svg = file.read
  svg = svg.sub('<svg', "<svg class='#{classes}'") if classes
  svg.html_safe
end
```

```erb
<%# In a template or component %>
<%= icon('explore', classes: 'w-5 h-5 fill-current text-gray-600') %>
```

This eliminates dark/white PNG pairs — color is controlled via Tailwind `text-*` or `fill-*` classes.

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

### Tier 3 — Introduce ViewComponent + Tailwind Components

| Task | Description |
|---|---|
| **T3-A** | **Install `view_component` and `lookbook` gems.** Configure Lookbook in development only. Verify `app/components/` is autoloaded. |
| **T3-B** | **Extract `UI::DetailSectionComponent`.** The 8 report section partials follow the same pattern. Create component accepting `title:`, `rows:` array of `{label:, value:}`. Replace all 8 partials. |
| **T3-C** | **Extract `UI::DatasetCardComponent` + make `_datasets.html.erb` data-driven.** Create `datasets.yml` or `Dataset` PORO. Replace 671-line hardcoded partial with a loop. |
| **T3-D** | **Add SVG icon system.** Export SVGs from Figma into `app/assets/images/icons/`. Add `icon()` helper. Replace all `image_tag` icon references and CSS `background-image` icon references. |
| **T3-E** | **Configure Figma design tokens in Tailwind.** Extract colors, spacing, font sizes from Figma. Define as `@theme` tokens in `app/assets/tailwind/application.css`. |

#### Tier 3 - Definition of done for every component

Every component task (T3-B, T3-C, and any future component extraction) is not complete until all three of the following exist:

| Requirement | Detail |
|---|---|
| **Unit test** | `test/components/ui/[name]_component_test.rb` using `ViewComponent::TestCase`. Must cover: default render, any meaningful variants, and nil/empty edge cases for optional arguments. |
| **Lookbook preview** | `app/components/previews/ui/[name]_component_preview.rb` with at least a default preview and one variant preview. This is the visual documentation — designers reference this alongside Figma. |
| **No ActiveRecord in test** | Tests pass plain data only (strings, arrays, hashes). If you find yourself loading a fixture or factory to test a component, the component is violating R-01. |

Example test structure:
```ruby
# test/components/ui/detail_section_component_test.rb
class UI::DetailSectionComponentTest < ViewComponent::TestCase
  def test_renders_title
    render_inline(UI::DetailSectionComponent.new(
      title: "Water Source",
      rows: [{ label: "Type", value: "Groundwater" }]
    ))
    assert_selector "h3", text: "Water Source"
    assert_selector "td", text: "Groundwater"
  end

  def test_handles_empty_rows
    render_inline(UI::DetailSectionComponent.new(title: "Empty", rows: []))
    assert_selector "h3", text: "Empty"
    refute_selector "td"
  end
end
```

### Tier 4 — Refactor `filter_controller.js`

| Task | Description |
|---|---|
| **T4-A** | **Define declarative `FILTERS` config array.** Each entry: `{ id, param, type, default }`. Single source of truth for the filter ↔ DOM mapping. |
| **T4-B** | **Rewrite `#collectFilters()` as a loop.** Replace 100-line imperative DOM-reading with a loop over `FILTERS`. |
| **T4-C** | **Rewrite `#restoreDomState()` as a loop.** Replace 100-line imperative DOM-writing with a loop over `FILTERS`. Adding a new filter is now one line in the config array. |
| **T4-D** | **Extract sub-controllers.** Split the 466-line controller: `FilterMenuController` (open/close/dismiss), `FilterLayoutController` (ResizeObserver logic), keeping `filter_controller` focused on state collect/restore/dispatch. |

### Tier 5 — Implement Histogram Slider

| Task | Description |
|---|---|
| **T5-A** | **Implement `slider_controller.js`.** Dual-handle range slider with histogram display. Uses commit-on-mouseup pattern — no server calls during drag. Fires `filters:changed` only on pointer release. |
| **T5-B** | **Add chart library via CDN.** Highcharts (referenced in existing TODO) or Chart.js (lighter). Load via CDN `<script>` tag consistent with existing pattern. |
| **T5-C** | **Wire slider into `FILTERS` config.** Slider entries use `type: 'range'`. `collectFilters()` reads min/max. `restoreDomState()` sets slider positions from URL params. |
| **T5-D** | **Complete `_filter_menus.html.erb` slider markup.** Structural shells already exist. Add `data-controller`, `data-target`, `data-action` attributes to activate `slider_controller`. |

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
