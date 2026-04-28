# Frontend Architecture Decision Rationale
**Why Hotwire + ViewComponent + Tailwind · April 2026**

---

## Decision

**Stay on Hotwire. Modernize deliberately with ViewComponent + Tailwind.**

Do not migrate to React. Do not introduce a JS build pipeline.

---

## 0.1 Context & Constraints

| Constraint | Detail |
|---|---|
| Future contributors | App is intended to be open-sourced. Convention matters more than cleverness. |
| JS bundler today | importmaps — no Node, no npm, no build pipeline. |
| Current state | Rails 8 Hotwire app, ~80% working patterns. DataTables is the primary legacy piece. |
| Upcoming work | UI cleanup, bug fixes, moderate feature work. Histogram slider is the most JS-intensive near-term item. |
| Design assets | Figma designs exist. SVG icons will replace current PNG system. |
| Map complexity | Mapbox GL JS is already a client-side JS layer and is framework-neutral regardless of choice. |
| Design system | Nice-to-have, not a hard requirement. No second consumer app exists yet. |

---

## 0.2 Options Evaluated

| Factor | Weight | Path A — Hotwire | Path B — React SPA |
|---|---|---|---|
| Time to ship | High | Short — incremental cleanup of working app | Long — full frontend rewrite required |
| Codebase disruption | High | Low — build on existing patterns | High — backend becomes JSON API, all views rewritten |
| Build tooling | High | None needed — importmaps stays | Node + Vite/webpack required |
| Open source readability | High | Rails conventions are widely understood | Common but requires two-ecosystem familiarity |
| Conventionality | High | Rails 8 default stack — fully conventional | Diverges from Rails defaults |
| Map feature (Mapbox) | Med | Framework-neutral — identical either way | Framework-neutral — identical either way |
| Filter state management | Med | Declarative config refactor solves duplication | React useState is cleaner, but rewrite cost is high |
| Design system potential | Med | ViewComponent + Lookbook — gem-extractable later | React + Storybook — industry standard |
| Histogram slider | Med | Stimulus, mouseup pattern — workable | React state — marginally cleaner |
| Table replacement | Med | Turbo Frame — conventional, eliminates jQuery | React data grid — more features, more complexity |
| Future design system sharing | Low | ViewComponent gem when second consumer exists | React component library — more ecosystem support |

**Result: Hotwire wins on every high-weight factor.**

---

## 0.3 Why Not React

React was a genuine option and would be right under different constraints. The specific reasons it was ruled out:

- **Build pipeline cost.** Introducing React requires Node, Vite or webpack, npm. The app runs on importmaps with zero build tooling. This is a significant infrastructure addition for a solo developer.
- **Rewrite cost.** The app is 80% working Hotwire patterns. React migration means rewriting the frontend from scratch while the backend simultaneously becomes a JSON API — two large parallel changes with high coordination cost.
- **The map argument doesn't hold.** The primary argument for React (better client-side state management) applies mainly to filter/histogram UI. This is solvable with a Stimulus refactor at a fraction of the cost. Mapbox GL JS is framework-neutral either way.
- **Open-source readability.** A future contributor familiar with Rails will immediately understand a Hotwire+ViewComponent app. A Rails-API+React app requires familiarity with two separate ecosystems and a build step.

**Trigger conditions to revisit this decision:**
- A dedicated frontend engineer joins with React as their primary skill
- A second app needs to share a component library and React is already in use there
- UI complexity grows significantly beyond current scope (real-time collaboration, offline support, complex multi-step wizards)
- The team explicitly decides to decouple the frontend as a separately deployed static site

---

## 0.4 Why ViewComponent + Tailwind

Staying on Hotwire does not mean staying on the current architecture. The existing codebase has clear structural problems that ERB partials alone cannot solve:

- **`_datasets.html.erb` is 671 lines of 27 identical hardcoded card blocks.** No loop, no data structure, no abstraction. Adding dataset 28 requires copying a block manually.
- **The 8 report section partials all follow the same pattern.** They are not reusable because partials have no enforced interface.
- **`water_tool.css` is 2,229 lines ported from a legacy PHP app.** Contains ~400 lines of dead code, styles for libraries not loaded, no connection to component structure.

ViewComponent solves these by giving each UI pattern a Ruby class with a typed interface, a co-located template, and a unit test. Tailwind makes styling a property of the component rather than a separate file that drifts out of sync.

**The combination produces a component library that:**
- Is testable in isolation (ViewComponent ships with test helpers)
- Is browsable via Lookbook without running the full app
- Can be extracted into a gem for a future second app with minimal effort
- Follows Rails conventions — no new paradigms for a Rails developer to learn
- Eliminates the dark/white PNG icon problem via SVG + Tailwind color classes

---

## 0.5 What This Decision Does Not Solve

- **The map is already a client-side JS app.** `map_controller.js` will remain a significant JS file regardless of framework. Hotwire doesn't change this.
- **The histogram slider is marginally harder in Stimulus than React.** The commit-on-mouseup UX pattern mitigates this. It is an acknowledged tradeoff.
- **Real-time collaborative features at scale** would warrant revisiting.
- **A React component library has broader ecosystem tooling** (Storybook, npm distribution, visual regression testing). ViewComponent + Lookbook is capable but smaller community.

---

## 0.6 Audit Findings That Confirmed the Decision

The April 2026 codebase audit (`docs/FE_AUDIT.md`) surfaced facts that directly supported staying on Hotwire:

| Finding | Implication |
|---|---|
| Tailwind already installed | One line to activate. No new dependency needed. |
| No ViewComponent yet | Clean slate — introduction only, no migration. |
| jQuery has one purpose | Loaded only for DataTables. Gone after Tier 2. |
| Turbo Streams unused | Room to grow within Hotwire before hitting any ceiling. |
| Turbo Drive never fires | Single-route SPA pattern already — Hotwire is already the right fit. |
| `filter_state.js` is clean | Well-designed singleton. Unchanged in refactored architecture. |
| `map_controller` is framework-neutral | Mapbox GL JS calls are identical in Hotwire or React. No map work is lost. |
| Mobile nav is a bug, not a design flaw | Unwired links are a copy-paste omission — not a Hotwire limitation. |

---

_This document should be committed alongside:_
- `docs/FE_Architecture_Plan.md`
- `docs/FE_AUDIT.md`
- `docs/arch_01_layer_structure.png`
- `docs/arch_02_filter_event_flow.png`
