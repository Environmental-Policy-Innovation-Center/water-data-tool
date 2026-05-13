# Agent Brief: Extract Filter Tab & Filter Menu ViewComponents

## Goal

Eliminate copy-paste repetition in `app/views/home/index.html.erb` and
`app/views/home/_filter_menus.html.erb` by extracting two ViewComponents:

1. **`UI::FilterTabComponent`** — the filter bar tab button (`<li>`) in the filter bar
2. **`UI::FilterMenuComponent`** — the dropdown menu shell with a content slot

---

## Files to Read First

1. `app/views/home/index.html.erb` lines 40–85 — the filter tab bar (`<ul id="filter-tabs">`) with 6 near-identical `<li>` blocks
2. `app/views/home/_filter_menus.html.erb` — the 6 dropdown menu containers (menus 1, 2, 3, 4, 5, 10)
3. `app/components/ui/nav_item_component.rb` and `.html.erb` — the existing component pattern to follow exactly
4. `spec/components/ui/nav_item_component_spec.rb` — the spec pattern to follow
5. `app/assets/tailwind/application.css` — has a `.container-menu` rule with `max-height` and scrollbar styles that should be revisited after extraction (see CSS note below)
6. `app/helpers/application_helper.rb` — defines the `icon` helper; must be `include ApplicationHelper` in any component that calls `icon`

---

## What Is Currently Repeated

### Filter tab buttons (index.html.erb) — 6 copies

Each `<li>` is structurally identical. Only four values change:

| Tab        | `menu_id` | `label`      | `li_id`                    |
|------------|-----------|--------------|----------------------------|
| Source     | 1         | "Source"     | source-filter-button       |
| Attributes | 2         | "Attributes" | attributes-filter-button   |
| Boundaries | 3         | "Boundaries" | boundaries-filter-button   |
| Compliance | 4         | "Compliance" | compliance-filter-button   |
| Population | 5         | "Population" | population-filter-button   |
| More       | 10        | "More"       | more-filter-button         |

The width class (`w-[122px]`, `w-[148px]`, `w-[154px]`, `w-[108px]`) also varies but can be
dropped — the button is fine as `w-auto` driven by label length once the label is in a
`<span class="flex-1">`.

The structure to collapse:
```html
<li id="source-filter-button" class="relative filter-1">
  <div class="container-filter-count-menu-1 absolute -top-2 right-0.5 hidden bg-brand-accent
              text-white text-[0.7em] rounded-full text-center py-px px-1.5 border border-white"
       aria-hidden="true">
    <span class="filter-count-group-1">0</span>
  </div>
  <button type="button"
          aria-expanded="false"
          aria-haspopup="true"
          data-menu="1"
          class="filter-menu-btn flex items-center gap-2 px-4 py-2 w-[122px] cursor-pointer
                 bg-white text-neutral-900 rounded-full border border-neutral-400
                 hover:bg-neutral-200 [&.active]:bg-brand-primary [&.active]:border-brand-primary
                 [&.active]:text-white"
          id="container-menu-btn-1"
          data-action="click->filter-menu#toggleMenu">
    <span class="flex-1">Source</span>
    <%= icon "nav-arrow-down", classes: "h-5 w-5 shrink-0 transition-transform [.active_&]:rotate-180" %>
  </button>
</li>
```

### Filter menu footer — 6 identical copies in _filter_menus.html.erb

```html
<div class="filter-menu-footer">
  <button type="button" class="btn-filters cursor-pointer" data-action="click->filter#reset">Reset</button>
  <button type="button" class="btn-filters btn-apply-filters cursor-pointer" data-action="click->filter#apply">Apply</button>
</div>
```

### Filter menu shell — 6 copies with unique inner content

```html
<div id="container-menu-1" class="container-menu" style="display:none;">
  <div id="main-filter-grp-1"></div>
  <div id="container-menu-1-items">
    <!-- UNIQUE content per menu -->
  </div>
  <div class="filter-menu-footer">
    <!-- Reset / Apply — identical every time -->
  </div>
</div>
```

Menu IDs in use: 1, 2, 3, 4, 5, 10.

---

## Proposed Component Interfaces

### `UI::FilterTabComponent`

Props:
- `menu_id:` (Integer) — used for all id/class derivations (e.g. `1` → `filter-1`,
  `container-filter-count-menu-1`, `filter-count-group-1`, `container-menu-btn-1`)
- `label:` (String) — visible button text ("Source", "Attributes", etc.)
- `li_id:` (String) — the `id` on the `<li>` ("source-filter-button", etc.)

The component renders the full `<li>` including the count badge and button.
Drop the explicit width class — use `w-auto` instead.

Call site after extraction:
```erb
<%= render UI::FilterTabComponent.new(menu_id: 1, label: "Source", li_id: "source-filter-button") %>
<%= render UI::FilterTabComponent.new(menu_id: 2, label: "Attributes", li_id: "attributes-filter-button") %>
<%# ... etc %>
```

### `UI::FilterMenuComponent`

Props:
- `menu_id:` (Integer) — used for `id="container-menu-X"` and `id="main-filter-grp-X"`

The component renders the shell (`container-menu` div + `main-filter-grp` placeholder +
footer) and **yields** a block for the unique inner content.

Call site after extraction:
```erb
<%= render UI::FilterMenuComponent.new(menu_id: 1) do %>
  <div id="container-menu-1-items">
    <h3>Primary type</h3>
    <!-- ... unique content ... -->
  </div>
<% end %>
```

The footer (Reset/Apply) is rendered by the component — not in the block.

---

## Conventions

- **TDD required**: write the spec first, confirm red, then implement, confirm green.
- Spec location: `spec/components/ui/filter_tab_component_spec.rb` and
  `spec/components/ui/filter_menu_component_spec.rb`
- Follow `spec/components/ui/nav_item_component_spec.rb` as the spec pattern.
- Follow `app/components/ui/nav_item_component.rb` / `.html.erb` as the component pattern.
- **`include ApplicationHelper`** in any component that calls `icon` in its template.
  (ActionView built-ins like `link_to` are available automatically; custom app helpers are not.)
- No inline styles. No new CSS classes. Tailwind utilities only on new HTML.
- Run `standardrb --fix` then `bin/ci` before reporting complete.

---

## CSS Note — tailwind/application.css

After `UI::FilterMenuComponent` owns the `container-menu` wrapper element, move the
`max-height: calc(100vh - 350px)` from the `.container-menu` CSS rule in
`app/assets/tailwind/application.css` onto the component template as a Tailwind arbitrary
class (`max-h-[calc(100vh-350px)]`).

The scrollbar pseudo-element rules (`::-webkit-scrollbar-*`) must remain in CSS — they cannot
be expressed as Tailwind utilities. Leave those in `tailwind/application.css` targeting
`.container-menu`.

After this move the `.container-menu` block in `tailwind/application.css` will only contain
the scrollbar rules, no `max-height`.

---

## Verify Complete When

- `bin/ci` passes (all specs green, standardrb clean, brakeman clean)
- `index.html.erb` filter tab bar has 6 `render UI::FilterTabComponent` calls instead of 6 `<li>` blocks
- `_filter_menus.html.erb` has 6 `render UI::FilterMenuComponent` block calls with no repeated footer HTML
- Lookbook previews exist for both components at `app/components/previews/ui/`
