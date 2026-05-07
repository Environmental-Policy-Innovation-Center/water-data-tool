# SVG Icon Status

_Last updated: May 2026 — PNG migration complete_

All SVG files live in `app/assets/images/icons/`. The `icon()` helper in `ApplicationHelper` inlines them.
All current SVGs use `fill="currentColor"` — color is controlled via Tailwind `text-*` classes.

---

## How Icons Are Used

There is now one canonical pattern:

| Pattern | Example | Status |
|---|---|---|
| `icon()` helper (inline SVG) | `<%= icon("arrow-down", classes: "h-3 w-3") %>` | **Only pattern — use for all new work** |

Legacy `image_tag` SVG and PNG patterns have been fully removed.

---

## Current Icon Inventory

All files in `app/assets/images/icons/` as of last audit:

| File | Active references | Notes |
|---|---|---|
| `alaska.svg` | none (future map inset use) | "AK" label for map insets |
| `arrow-down.svg` ✅ | `_filter_menus.html.erb` ×4 via `icon()` | Small chevron (Heroicons style) |
| `arrow-downward.svg` | none yet | Full arrow with shaft pointing down |
| `arrow-upward.svg` | none yet | Full arrow with shaft pointing up |
| `close.svg` ✅ | `index.html.erb` (report close) via `icon()` | |
| `collapse.svg` ✅ | `_sidebar.html.erb` toggle button via `icon()` | Fullscreen collapse (inward arrows) |
| `data.svg` ✅ | `_sidebar.html.erb`, `index.html.erb` mobile menu via `icon()` | |
| `documentation.svg` ✅ | `_sidebar.html.erb`, `index.html.erb` mobile menu via `icon()` | |
| `downloads.svg` ✅ | `_sidebar.html.erb`, `index.html.erb` mobile menu via `icon()` | Also used in table view export button |
| `email.svg` ✅ | `_sidebar.html.erb` (×2), `index.html.erb` mobile menu via `icon()` | |
| `expand.svg` ✅ | `_sidebar.html.erb` toggle button via `icon()` | Fullscreen expand (outward arrows) |
| `explore.svg` ✅ | `_sidebar.html.erb`, `index.html.erb` mobile menu via `icon()` | |
| `external-link.svg` ✅ | `_sidebar.html.erb` (×3) via `icon()` | |
| `feedback.svg` ✅ | `index.html.erb` mobile menu via `icon()` | |
| `filter.svg` ✅ | `_datasets.html.erb` via `icon()` | Three horizontal lines |
| `github.svg` ✅ | `index.html.erb` mobile menu via `icon()` | |
| `hawaii.svg` | none (future map inset use) | "HI" label for map insets |
| `info.svg` | none yet | |
| `locate.svg` | none yet | |
| `map-filters.svg` | none yet | Funnel shape |
| `map.svg` ✅ | `index.html.erb` map/table toggle via `icon()` | |
| `mobile-menu.svg` ✅ | `index.html.erb` mobile header via `icon()` | Hamburger menu |
| `nav-arrow-down.svg` ✅ | `index.html.erb` filter tabs (×6) via `icon()` | Rotates 180° when active |
| `nav-arrow-up.svg` | none (rotation approach used instead) | |
| `navigation-hover.svg` | none yet | Navigation pill shape (hover state) |
| `navigation-on.svg` | none yet | Navigation pill shape (active state) |
| `print.svg` ✅ | `index.html.erb` report print button via `icon()` | |
| `search.svg` | none yet | |
| `sort.svg` | none yet | |
| `table.svg` ✅ | `index.html.erb` map/table toggle via `icon()` | |
| `tooltip-down.svg` | none yet | |
| `tooltip-up.svg` | none yet | |
| `zoom-in.svg` | none yet | |
| `zoom-out.svg` | none yet | |

---

## PNG Deprecation Status — COMPLETE ✅

All `icon-*.png` files have been deleted from `app/assets/images/`. Only logo PNGs remain:
- `EPIC-logo.png`
- `logo-drinking-water-explorer.png`
- `logo-drinking-water-explorer-placeholder.png`

No `water_tool.css` rules reference PNG background-images any longer.

---

## Sidebar Nav Icon Pattern

Nav links use `[&.active]:bg-brand-primary [&.active]:text-white` Tailwind classes. Since SVGs use `fill="currentColor"`, the icon automatically inherits the link text color — dark in default state, white when active. No separate dark/white SVG variants needed.

Filter tab arrows use a single `nav-arrow-down` icon with `[.active_&]:rotate-180` to flip direction when the dropdown is open.

---

## Open Items

- `navigation-hover.svg` / `navigation-on.svg` — not yet wired to any HTML element
- `locate.svg` — no view reference yet (was `icon-find-location.png`, `icon-zoom-to-location.png`)
- `map-filters.svg`, `info.svg` — available but the mobile UI elements they were for no longer exist
- Sidebar collapse/expand toggle button (`#toggle-button`) has no JavaScript handler — the `collapse`/`expand` icon toggle is CSS-ready (`[.close_&]:` variants) but will need a Stimulus action when the feature is implemented
- Territory icon approach (`PR`, `GU`, `MP` text buttons on map) — determine if SVG icons are needed or if text labels are sufficient; `alaska.svg` and `hawaii.svg` exist as reference
