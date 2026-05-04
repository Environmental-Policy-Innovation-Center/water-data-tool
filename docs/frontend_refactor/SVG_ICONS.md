# SVG Icon Status

_Last updated: May 2026_

All SVG files live in `app/assets/images/icons/`. The `icon()` helper in `ApplicationHelper` inlines them.
All current SVGs have been updated to use `fill="currentColor"` — color is controlled via Tailwind `text-*` classes.

---

## SVGs Still Needed (blockers for full PNG deprecation)

These icons are currently rendered via PNG (CSS `background-image` or `image_tag`). SVG versions are needed to complete the migration.

| File needed | Replaces | Used in |
|---|---|---|
| `print.svg` | `icon-print.png` | `index.html.erb` via `image_tag` |
| `nav-arrow-down.svg` | `icon-nav-arrow-down.png` | `water_tool.css` — sidebar nav dropdown |
| `nav-arrow-up.svg` | `icon-nav-arrow-up.png` | `water_tool.css` — sidebar nav dropdown |
| `sort.svg` | `icon-sort.png` | `water_tool.css` — datasets sort button |
| `arrow-down.svg` | `icon-arrow-down-dark.png`, `icon-arrow-down-white.png` | `water_tool.css` — mobile sort indicators |
| `close-white.svg` | `icon-close-white.png` | `water_tool.css` — mobile overlay close (covered by `close.svg` + `currentColor` once CSS is migrated) |
| `map-filters.svg` | `icon-map-filters.png` | `water_tool.css` — Mapbox popup filter button |

> Note: with `currentColor`, `close.svg` covers all close variants — `close-white.svg` is only needed if the CSS `background-image` reference is kept as-is rather than converted to an inline SVG via the `icon()` helper.

---

## Ideal End State — Full `currentColor` SVG Set (~28 files)

Once all icons are sourced as `currentColor` SVGs, dark/white PNG pairs collapse to a single file. This is the target file list:

| File | Replaces |
|---|---|
| `arrow-down.svg` | `icon-arrow-down-dark.png`, `icon-arrow-down-white.png` |
| `close.svg` ✅ | `icon-close.png`, `icon-close-dark.png`, `icon-close-white.png` |
| `collapse.svg` ✅ | `icon-collapse.png` |
| `data.svg` | `icon-data-dark.png`, `icon-data-white.png` |
| `documentation.svg` | `icon-documentation-dark.png`, `icon-documentation-white.png` |
| `downloads.svg` | `icon-downloads-dark.png`, `icon-downloads-white.png` |
| `email.svg` ✅ | `icon-email.png` |
| `expand.svg` ✅ | `icon-expand.png` |
| `explore.svg` | `icon-explore-dark.png`, `icon-explore-white.png` |
| `external-link.svg` ✅ | `icon-ext-link.png` |
| `feedback.svg` ✅ | `icon-feedback.png` |
| `filter.svg` ✅ | `icon-filter.png` |
| `github.svg` ✅ | `icon-GitHub.png` |
| `info.svg` ✅ | `icon-info.png` |
| `locate.svg` ✅ | `icon-find-location.png`, `icon-zoom-to-location.png` |
| `map.svg` | `icon-map-toggle-dark.png`, `icon-map-toggle-white.png` |
| `map-filters.svg` | `icon-map-filters.png` |
| `mobile-menu.svg` ✅ | `icon-mobile-menu.png` |
| `nav-arrow-down.svg` | `icon-nav-arrow-down.png` |
| `nav-arrow-up.svg` | `icon-nav-arrow-up.png` |
| `print.svg` | `icon-print.png` |
| `search.svg` ✅ | — |
| `sort.svg` | `icon-sort.png` |
| `table.svg` | `icon-table-dark.png`, `icon-table-white.png` |
| `tooltip.svg` | `icon-tooltip-dark.png`, `icon-tooltip-white.png` |
| `x.svg` | `icon-mobile-menu-x.png` |
| `zoom-in.svg` ✅ | — |
| `zoom-out.svg` ✅ | — |

✅ = file already exists in `app/assets/images/icons/` with `currentColor`

### Files to consolidate once end state is reached

When the above single files are in place, these current dark/white pairs in `app/assets/images/icons/` can be deleted:

- `navigation-hover.svg` + `navigation-on.svg` → replaced by `nav-arrow-down.svg` / `nav-arrow-up.svg`
- `tooltip-down.svg` + `tooltip-up.svg` → replaced by `tooltip.svg`

> **Note:** Consolidating pairs requires updating all call sites in views and CSS at the same time. Do not delete a pair file until the code referencing it has been updated to use the single replacement file with a Tailwind `text-*` color class.
