# Mobile-First Tailwind Refactor Checklist

Branch: `ref/implement-tailwinds-mobile-first-style-pattern`

This is a working checklist for the mobile-first CSS refactor. Items are ordered by priority. See `A11Y_AND_MOBILE_GUIDE.md` and `TAILWINDS_CSS_GUIDE.md` for background.

---

## CRITICAL (correctness / accessibility)

- [x] **Viewport meta** — `app/views/layouts/application.html.erb`
  - Remove `user-scalable=no` and `maximum-scale=1` (WCAG 1.4.4 violation; blocks pinch-zoom on mobile)
  - ✅ Fixed: `<meta name="viewport" content="width=device-width, initial-scale=1">`

- [x] **Hover guards** — multiple files
  - Bare `hover:` fires on touchscreens as a "sticky" state on tap. Must be guarded.
  - Desktop-only elements (sidebar nav, datasets panel buttons): use `md:hover:`
  - Elements visible on both mobile and desktop (filter rows, filter menu icon buttons): use `[@media(hover:hover)]:hover:`
  - ✅ Fixed in: `nav_item_component.rb`, `application_helper.rb` (FILTER_ROW_CLASSES), `_datasets.html.erb`, `_filter_menus.html.erb`, `group_range_component.html.erb`
  - ⬜ Still to fix: `_table.html.erb` — see Pattern A below
  - ⚠️ Needs post-deploy test on a real touch device to verify no sticky hover artifacts

- [x] **`max-[640px]:hidden` anti-pattern** — `app/views/home/_filter_menus.html.erb` line ~290
  - Max-width overrides fight the mobile-first cascade; invert to `hidden sm:block`
  - Fix: `class="... max-[640px]:hidden"` → `class="... hidden sm:block"`

- [x] **Mobile menu bottom padding** — `app/views/home/index.html.erb`
  - Mobile nav overlay `py-[60px]` gives only 60px bottom clearance, but the footer is ~108px tall when `@last_updated` is present. "Contact EPIC" link is hidden under the footer.
  - Fix: change `py-[60px]` → `pt-[60px] pb-36` on the mobile menu inner scroll container

---

## Sidebar

- [x] **No-scroll sidebar** — `app/views/home/_sidebar.html.erb`
  - `overflow-y-auto overflow-x-hidden` → `overflow-hidden` (sidebar is fixed height; it must never scroll)
  - ✅ Fixed

- [x] **Sidebar footer spacing** — `app/views/home/_sidebar.html.erb`
  - Reduced to fit: `py-4→py-2` on wrapper, `py-3` removed from EPIC icon div, `my-6 space-y-2→my-2 space-y-2`, `mt-3` added to last-updated paragraph
  - ✅ Fixed

- [x] **Filter tab breakpoints** — `app/javascript/controllers/filter_layout_controller.js`
  - Reverted to original values (1190 / 1040 / 880 / 730 / 580) after confirming they prevent Source tab from overlapping the geocoder
  - ✅ Fixed

---

## Mobile Filter UX — future work

- [ ] **Mobile: replace tab/More paradigm with a single scrollable filter sheet**
  - On desktop, filters are tabbed (Source / Attributes / Boundaries / Compliance / Population / More). As the container narrows, tabs collapse into the "More" menu via `filter_layout_controller.js`.
  - On mobile, all filters end up in "More" — requiring an extra tap just to see any filters.
  - **Desired behavior:** On mobile (below `sm:` / 640px), skip the tab UI entirely. A single "Filters" button opens a full-screen scrollable sheet showing all filter groups in order. The "More" tab is never rendered.
  - **Scope:** Requires a new mobile rendering path in `filter_layout_controller.js` (detect mobile, bypass the tab-collapse logic), a new full-screen overlay component, and hiding `#filter-tabs` + individual tab buttons on mobile. Non-trivial — treat as its own feature.

---

## Pattern A — Table hover guards

- [x] **`app/views/home/_table.html.erb`** — guard all remaining `hover:` states
  - Line 26: `group-hover:bg-blue-50` → `md:group-hover:bg-blue-50` ✅
  - Line 155: `hover:bg-blue-50` on `<tr>` → `md:hover:bg-blue-50` ✅
  - Line 165: `hover:underline` on PWS name link → `md:hover:underline` ✅
  - Lines 272, 282, 310, 320: `hover:bg-gray-50` → `md:hover:bg-gray-50` (replace_all, 4 occurrences) ✅

---

## Pattern B — `sm:` used where `md:` is correct

The app's desktop layout starts at `md:` (768px). Several elements use `sm:` (640px) as a desktop breakpoint, which is too narrow and causes premature layout shifts.

Files to audit:
- [x] `app/views/home/index.html.erb` — all `sm:` usages are intentional (sidebar/mobile overlay pattern at 640px)
- [x] `app/views/home/_datasets.html.erb` — no `sm:` usage
- [x] `app/views/home/_table.html.erb` — no `sm:` usage

---

## Pattern C — Fixed pixel widths that break narrow viewports

- [x] Audit for hardcoded `w-[Xpx]` values that do not have a mobile-width fallback
  - All fixed widths are either safe exceptions or desktop-only elements. No changes needed.

---

## Pattern D — Touch target sizes

- [x] Confirm primary interactive controls (buttons, nav items) present ≥ 44×44px hit area on mobile
  - Nav items `py-2.5` + `text-base` 24px line-height = 44px ✓
  - Map/Table toggle pills (`sm:hidden`) — phone-only, not a target use case; skipped
  - Hamburger button: added `p-2.5` → 10+24+10 = 44px tap area ✅

---

## Pattern E — Remaining `max-*` overrides to invert

- [x] No `max-[Xpx]:` responsive overrides found in views or components. Only `max-w-[...]` width constraints and the intentional `max-sm:!hidden` / `max-md:!hidden` added in this refactor.

---

## Notes

- **Breakpoint reference for this app:**
  - `sm:` = 640px — use only for small structural changes; not the desktop threshold
  - `md:` = 768px — primary desktop layout breakpoint
  - `lg:` = 1024px — secondary desktop polish
  - `xl:` = 1280px — strictly-desktop-only structural elements (e.g. sidebar show/hide matches `AUTO_COLLAPSE_BELOW = 1280` in sidebar_controller.js)

- **Hover guard rules:**
  - `md:hover:` — element only exists / is interactive at desktop widths
  - `[@media(hover:hover)]:hover:` — element is interactive on both mobile and desktop

- **Sidebar collapse:** JS `AUTO_COLLAPSE_BELOW = 1280` collapses the sidebar below 1280px window width. CSS shows/hides sidebar at `sm:` (640px). Between 640–1280px, sidebar is visible but collapsed (icon-only, 80px wide). `#shiftContent` resets left offsets only below 640px (when sidebar is fully hidden).
