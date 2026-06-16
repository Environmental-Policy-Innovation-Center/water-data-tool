# Text Color Audit

## Context

### What
An audit of text color usage across the app against the custom neutral token scale defined
in `app/assets/tailwind/application.css`.

### Why
During work on `CircleButtonComponent` and `CircleToggleComponent`, a broader color
consistency issue surfaced: several components use off-theme neutral values (`neutral-500`,
`neutral-600`, `neutral-800`), Tailwind's default `gray-*` scale (different hex values from
the custom scale), and hardcoded hex literals. This causes subtle visual inconsistency and
makes future theming changes harder to apply uniformly.

---

## Discovery

### Custom Theme Scale

Only these neutral tokens are defined in `app/assets/tailwind/application.css`:

| Token | Hex | Notes |
|---|---|---|
| `neutral-900` | `#181818` | Near-black. Active/emphasis states. |
| `neutral-700` | `#565656` | Standard body/label text. Established baseline. |
| `neutral-400` | `#bfbfbf` | Borders, secondary UI chrome. |
| `neutral-200` | `#dedede` | Light borders. |
| `neutral-100` | `#f5f5f5` | Light backgrounds. |

**`neutral-500`, `neutral-600`, `neutral-800` are NOT in the custom scale.** When used, they
fall through to Tailwind's default scale (different hex values), producing inconsistent results.

`brand-dark: #13171F` is also defined but not currently used via a Tailwind class anywhere —
referenced only in a comment.

### What Has Already Been Resolved

- **`checkbox-circle-*` SVGs** — both use `currentColor`. Pattern is `text-neutral-900` (on) / `text-neutral-700` (off). Consistent across all render sites.
- **`CircleButtonComponent`** — hardcoded `text-[#444]` replaced with `text-neutral-700`.
- **Filter row labels** — `FILTER_ROW_CLASSES` updated to `[&_label]:text-neutral-700`. All native filter labels now match `CircleToggleComponent` label style.
- **`CategoryHeaderRowComponent`** — `text-neutral-500` (off-scale) changed to `text-neutral-700`.
- **`_sidebar.html.erb`** — two `text-[#565656]` literals replaced with `text-neutral-700`.

### Remaining Inconsistencies

**Off-scale neutral values** (`neutral-600`, `neutral-800` don't exist in the custom scale):

| File | Class | Context |
|---|---|---|
| `app/components/ui/filter_menu_panel_component.rb` | `text-neutral-800` | Panel nav link text |
| `app/components/filters/group_range_component.html.erb` | `text-neutral-800` | Info tooltip spans (×2) |
| `app/views/home/_filter_menus.html.erb` | `text-neutral-800` | Info tooltip spans (×2) |
| `app/views/home/_datasets.html.erb` | `text-neutral-600` | Italic metadata labels |
| `app/views/home/_datasets.html.erb` | `text-neutral-500` | Dropdown arrow `▾` character |

**Wrong scale entirely** (`text-gray-*` instead of `text-neutral-*`):

| File | Classes | Context |
|---|---|---|
| `app/components/ui/dataset_card_component.html.erb` | `text-gray-600`, `text-gray-800`, `text-gray-900` | Card title, description, metadata |
| `app/views/public_water_systems/sections/_violations.html.erb` | `text-gray-700`, `text-gray-800` | Violation count table cells |
| `app/views/layouts/report.html.erb` | `text-gray-800` (on `<body>`) | Print/PDF layout — may be intentional |
| `app/components/report/header_component.html.erb` | `text-gray-600` | Report header — same caveat |
| `app/components/ui/detail_section_component.html.erb` | `text-gray-800` | PWS detail section values |

**Hardcoded hex values remaining:**

| File | Value | Element | Suggested replacement |
|---|---|---|---|
| `app/views/home/_sidebar.html.erb` | `text-[#102033]` | Intro paragraph | `text-neutral-900` or new `brand-dark` token |
| `app/views/home/_filter_menus.html.erb` line 39 | `text-[#333]` | Combobox list items | `text-neutral-700` |
| `app/views/home/index.html.erb` line 15 | `color: #565656` (inline style) | Mapbox marker label | CSS custom property `--color-neutral-700` |

**Intentional deviations — do NOT change:**

| Class | Where | Why |
|---|---|---|
| `text-neutral-900` | Active tabs, nav items, bold category labels | Emphasis / active state |
| `text-neutral-400` | Violation count secondary labels | De-emphasized helper text |
| `text-neutral-300` | Drag handle icon | Intentionally subtle |
| `text-[#888]` | Disabled "Boil water notices" label | Disabled state |
| `text-white` | Dark backgrounds | Correct |
| `text-brand-primary` | App title, brand elements | Brand color |

### Decisions Needed Before Implementing

1. **`text-neutral-800`** — map to `text-neutral-900` (darker) or `text-neutral-700` (standard label)? Usages are tooltip text and panel nav links — probably `text-neutral-700`.
2. **`text-[#102033]`** (sidebar intro paragraph) — deliberate brand navy deserving its own token (e.g. `brand-dark`), or simplify to `text-neutral-900`?
3. **Report layout** (`layouts/report.html.erb`, `report/` components) — align to main app neutral scale, or treat as a separate visual context and leave alone?
4. **`text-gray-*` in `dataset_card_component`** — straightforward migration, but verify visually before shipping.

### Recommended `text-gray-*` → `text-neutral-*` Mapping

| `text-gray-*` | Nearest neutral equivalent |
|---|---|
| `text-gray-600` | `text-neutral-700` |
| `text-gray-700` | `text-neutral-700` |
| `text-gray-800` | `text-neutral-900` |
| `text-gray-900` | `text-neutral-900` |

Verify visually before shipping — `gray-800` and `gray-900` both map to `neutral-900`, which
may flatten contrast in some contexts.

---

## Checklist

- [ ] Resolve decisions above with the team
- [ ] Replace off-scale `neutral-*` values per decisions
- [ ] Migrate `text-gray-*` → `text-neutral-*` in non-report components
- [ ] Decide on report layout — migrate or leave alone
- [ ] Replace remaining hardcoded hex values
- [ ] Visual review pass — spot check key components before merging
- [ ] Run `bin/ci` — all specs green

---

> **Cleanup:** Delete this file when all inconsistencies are resolved. Reference the closing PR in the commit message.
