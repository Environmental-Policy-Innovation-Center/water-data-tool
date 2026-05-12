# Rails + Tailwind: Mobile & Accessibility (a11y)

**Audience:** Engineers and AI agents working on ERB views, Stimulus, and Tailwind in this app.  
**Goal:** One set of rules—mobile-first layout, usable touch targets, and WCAG-minded patterns—so new UI stays consistent without re-deriving standards each time.

### Desktop-primary product, mobile-first CSS

**Desktop is the primary use case** for this app: depth of features, density, keyboard workflows, and QA emphasis can all stay desktop-centered.

**Mobile-first Tailwind** is only an **authoring order** for responsive classes (defaults for narrow viewports, then `md:` / `lg:` to add desktop layout). It does not mean “mobile users come first” or that desktop quality is sacrificed. Rich desktop UI is expressed at larger breakpoints and in regions that are `hidden` until `md:`—the same patterns this guide recommends.

Those two ideas are **not in conflict**: you optimize the product for desktop while writing styles small-to-large so narrow viewports stay coherent without a second cascade of `max-*` overrides.

---

## 1. Mobile-friendly (mobile-first)

### How we work

- **Mobile-first:** Write the default class for the smallest screen, then add `md:`, `lg:`, etc., only where larger breakpoints need different layout or spacing.
  - **Good:** `class="p-4 md:p-8"` — tight on phones, roomier on desktop.
  - **Avoid:** Desktop-sized spacing as the default and “fixing” it with `max-*` overrides everywhere.

- **Prefer min-width breakpoints over max-width:** Use `md:`, `lg:` instead of `max-md:`, `max-lg:` unless you have a specific reason. Heavy use of `max-*` tends to fight specificity and is harder to reason about than a single upward cascade.

- **Fluid layout:** Prefer `w-full`, fractional grids (`grid-cols-*`), and `flex-1` over fixed pixel widths like `w-[500px]`, which break small screens.

- **Responsive visibility:** Toggle whole regions with pairs such as `hidden md:block` (mobile menu vs desktop sidebar) or `block md:hidden` when the design calls for different chrome per breakpoint.

- **Touch targets:** Interactive controls (buttons, links that act as buttons, major taps) should present a hit area of at least **44×44 CSS pixels** (e.g. `min-h-11 min-w-11`, `h-12 px-6`, or enough padding that the visual + padding meets the minimum).

### Example — layout (ERB)

```erb
<%# One column on small screens, two on md+ %>
<div class="grid grid-cols-1 gap-6 p-4 md:grid-cols-2 md:p-8">
  <section class="w-full rounded-xl bg-slate-50 p-6">
    <h2 class="text-lg font-bold">Feature A</h2>
  </section>
  <section class="w-full rounded-xl bg-slate-50 p-6">
    <h2 class="text-lg font-bold">Feature B</h2>
  </section>
</div>
```

---

## 2. Accessibility (a11y)

### Principles

- **Semantic HTML:** Use `<nav>`, `<main>`, `<section>`, `<button>`, headings in order, etc., instead of a `<div>` when the element has that role. Rails helpers like `button_to`, `link_to`, and `form_with` help keep semantics correct if you avoid overriding them with non-interactive wrappers.

- **Visible keyboard focus:** Do not use `focus:outline-none` (or equivalent) without a **visible** replacement. Prefer **`focus-visible:`** rings or outlines so pointer users are not flooded with focus chrome while keyboard users still get a clear indicator:
  - e.g. `focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-600`
  - or `focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-blue-600`

- **Names for assistive tech:** Prefer a **visible** label when you can. For icon-only controls, a single `aria-label` on the `<button>` / link is usually enough (see below). Use Tailwind’s **`sr-only`** only when you need **real text in the DOM** (see below)—it is not an ARIA attribute, just visually hidden text.

- **ARIA + state styling:** When you use ARIA attributes (`aria-expanded`, `aria-selected`, etc.), you can mirror state in Tailwind with variants such as `aria-expanded:rotate-180` or `aria-selected:bg-blue-100` so open/selected UI stays in sync with what assistive tech announces—**after** the behavior is correct in HTML/JS.

- **Color contrast:** Aim for **WCAG 2.1 AA** for normal text (roughly **4.5:1** contrast against its background). Dark text on light backgrounds (e.g. `text-slate-900` on `bg-white`) is a safe default; test custom brand pairs.

- **Reduced motion:** Respect `prefers-reduced-motion`: gate motion with `motion-safe:` or strip transitions with `motion-reduce:transition-none` (and avoid autoplaying large motion where possible).

### Accessible names: ARIA first, `sr-only` when the DOM needs text

**Tailwind-only styling:** `sr-only` is a **built-in Tailwind utility** (see [Tailwind screen-reader utilities](https://tailwindcss.com/docs/screen-readers)). It is **not** an HTML tag—you put it on an element as `class="sr-only"` (often a `<span>`). That still counts as using Tailwind exclusively; do not reimplement screen-reader-only text with custom CSS unless Tailwind is unavailable.

Listing both is only confusing if they sound like two equal “tags” for the same job. They are **different layers**:

- **`aria-*` attributes** — Part of the **accessibility API** (name, description, state). You need these for behavior (`aria-expanded`, etc.) and they are the **default** for a **short, single** accessible name (e.g. icon-only: `aria-label="Download report (PDF)"`).
- **`sr-only`** — A **Tailwind class** on normal elements so **text stays in the DOM** but is hidden visually. It is **not** a substitute for `aria-expanded` / `aria-selected` / roles.

**Does “only ARIA” cover everything?** For **naming** many controls, yes: `aria-label`, `aria-labelledby`, and `aria-describedby` cover most cases. **`sr-only` is still useful** when the best pattern is **text nodes** in the markup—for example: an `aria-describedby` target that is a sentence or two of help (often a `<p id="..." class="sr-only">`), visible label plus **extra** AT-only wording without duplicating `aria-label`, or workflows where copy lives in the template as text for i18n/tools. **`aria-label` is plain text only** (no markup inside the attribute); longer structured hints often belong in hidden **content** referenced by `aria-describedby`, sometimes implemented with `sr-only`.

**Default in this app:** For **icon-only** buttons/links, use **`aria-label`** on the interactive element unless you have a reason to use visible + `sr-only` or `aria-labelledby` instead. Do **not** repeat the same string in **`aria-label` and** an inner **`sr-only`** span.

| Mechanism | What it is | Typical use |
| --------- | ----------- | ----------- |
| **`aria-label` / `aria-labelledby` / `aria-describedby`** | **HTML attributes** for **name** and **description** (by id). | **Default** for icon-only name; tie to help text id for longer descriptions. |
| **`aria-expanded`, `aria-selected`, `aria-current`, …`** | **State / relationship** in the accessibility API. | Menus, tabs, toggles—required semantics; not replaceable by `sr-only`. |
| **`sr-only`** | **CSS** utility: text in the tree, hidden visually. | Help copy targeted by `aria-describedby`, extra AT line with visible label, or other cases where **DOM text** fits better than one `aria-label` string. |
| **Tailwind `aria-expanded:…`, `aria-selected:…`, etc.** | **Styling** from the DOM attribute value. | Cosmetic; only after real `aria-*` is set in HTML/JS. |

### Example — icon-only control (default: `aria-label`) (ERB)

```erb
<%# Icon-only: name via aria-label; decorative icon hidden from AT %>
<%= button_tag type: "button",
    aria: { label: "Download report (PDF)" },
    class: "inline-flex min-h-11 min-w-11 items-center justify-center rounded-md bg-blue-600 p-2 text-white hover:bg-blue-700 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-600 motion-reduce:transition-none" do %>
  <svg class="h-5 w-5" aria-hidden="true"><%# icon markup %></svg>
<% end %>
```

### Example — full-width on mobile, constrained on desktop (ERB)

```erb
  get height on small screens; focus ring for keyboard users %>
<%= button_to logout_path, method: :delete,
    class: "inline-flex h-12 w-full items-center justify-center rounded-md bg-red-600 px-6 text-white hover:bg-red-700 focus-visible:ring-2 focus-visible:ring-red-500 focus-visible:ring-offset-2 md:w-auto" do %>
  <span aria-hidden="true" class="me-2"><i class="fa-solid fa-sign-out"></i></span>
  Log out
<% end %>
```

*(If the design is icon-only, set a single **`aria-label`** on the control (see earlier example), or use `sr-only` / `aria-labelledby` when that fits the markup better—never duplicate the same wording in both `aria-label` and `sr-only`.)*

---

## 3. Quick reference (humans & agents)

| Topic | Typical Tailwind / pattern | Why |
| ----- | -------------------------- | --- |
| Mobile-first | `w-full md:w-auto`, `p-4 md:p-8` | Defaults match small screens; desktop is additive. |
| Breakpoints | Prefer `md:`, `lg:` over `max-md:` | Clearer cascade, fewer specificity fights. |
| Layout | `grid grid-cols-1 md:grid-cols-*`, `flex-1` | Adapts without fixed pixel widths. |
| Visibility | `hidden md:block`, `md:hidden` | Swap chrome by breakpoint. |
| Touch | `min-h-11 min-w-11`, `h-12 px-*` | ~44px minimum hit area. |
| Focus | `focus-visible:ring-*`, `focus-visible:outline-*` | Keyboard-visible; less noise for mouse. |
| Accessible name | **`aria-label`** (default for icon-only), visible text, or `aria-labelledby` | One primary source per control; do not duplicate with `sr-only`. |
| Extra help / long hint | `aria-describedby` → element (often `class="sr-only"` on that element) | Longer copy as DOM content, not crammed into `aria-label`. |
| Screen reader–only copy | `sr-only` on a real element | When DOM text is the right shape (e.g. description target, i18n span). |
| ARIA state | `aria-expanded`, `aria-selected`, etc. on the element | Required semantics for widgets; not replaced by `sr-only`. |
| ARIA styling | Tailwind `aria-expanded:*`, `aria-selected:*` | Cosmetic; must mirror attributes set in HTML/JS. |
| Contrast | Strong text/background pairs | Target WCAG AA (~4.5:1 for body text). |
| Motion | `motion-safe:`, `motion-reduce:transition-none` | Vestibular / reduced-motion preferences. |

---

## 4. Pre-ship checklist (short)

- [ ] New interactive elements meet **~44×44px** touch minimum on primary actions.
- [ ] Layout uses **fluid** units and **mobile-first** classes; no accidental desktop-only widths.
- [ ] Every interactive control has a **name** (visible text, **`aria-label`** for icon-only by default, or `aria-labelledby` / `aria-describedby` as needed—not the same string twice in `aria-label` + `sr-only`).
- [ ] Focus is **never** removed without a **visible** `focus-visible` (or equivalent) replacement.
- [ ] Color choices meet **contrast** intent for the text size and role.
- [ ] Animations respect **`prefers-reduced-motion`** where you added motion.

This document is the single source of truth for these topics in the water-data-tool frontend.
