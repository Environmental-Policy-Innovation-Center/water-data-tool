# Frontend Architecture Decision

> Should this app stay on Hotwire (Rails-rendered) or move to a React SPA?
> This document captures the tradeoffs, infrastructure implications, and open questions to resolve before committing to either path.

---

## What We Have Today

A **Rails 8 Hotwire app** — the server renders HTML, JavaScript handles interactions on top of it.

```
Browser loads /
  └── HomeController#index renders the app shell (HTML)
        ├── map_controller.js    → Mapbox GL JS (always client-side, either way)
        ├── filter_controller.js → collects filter state, dispatches filters:changed
        ├── table_controller.js  → DataTables AJAX → GET /table.json (server renders nothing, jQuery renders rows)
        └── <turbo-frame>        → stats bar, report panel (server renders HTML fragments)
```

The table is the odd one out — it uses a jQuery-era library (DataTables) carried over from the legacy app, not Hotwire conventions. Replacing it with a Turbo Frame table is already the highest-priority item in TODO.md.

---

## The Two Paths

### Path A — Stay on Hotwire (finish what's started)

Server renders HTML. Stimulus handles DOM interactions. Turbo Frames handle partial page updates.

```
Browser                          Rails Server
──────                           ────────────
filters:changed event
  ├── GET /map        ────────►  HomeController#map     → { pwsids: [...] }
  ├── GET /table      ────────►  HomeController#table   → renders _table.html.erb (Turbo Frame)
  └── GET /stats      ────────►  StatsController#show   → renders _stats.html.erb (Turbo Frame)
```

### Path B — React SPA

Browser owns all rendering. Rails becomes a pure JSON API.

```
Browser (React)                  Rails Server (API only)
───────────────                  ──────────────────────
filter state change
  ├── GET /api/map    ────────►  HomeController#map     → { pwsids: [...] }  (unchanged)
  ├── GET /api/systems ───────►  PublicWaterSystemsController#index → { results: [...] }
  └── GET /api/stats  ────────►  StatsController#show   → { counts: {...} }  (JSON only)
```

---

## Side-by-Side Comparison

| | Hotwire | React SPA |
|---|---|---|
| **Who renders HTML** | Rails server | Browser (React) |
| **Table implementation** | Turbo Frame + server partial | React data grid component |
| **Filter → update flow** | `filters:changed` → Turbo Frame reload | React state → re-render |
| **Map (Mapbox)** | Stimulus controller — unchanged | React component — unchanged |
| **Reusable UI components** | Rails partials + ViewComponent gem | React components (Storybook) |
| **Design system support** | Limited — partials are not composable like components | Strong — industry standard |
| **Build tooling** | None (importmap, no bundler needed) | Node, Vite/webpack, npm |
| **Team skillset** | Ruby/Rails primary | JavaScript/React + Rails API |
| **Backend role** | Renders HTML + serves data | Serves data only (JSON API) |
| **Deployment complexity** | Low | Higher (separate build step or asset pipeline) |
| **Time to production** | Shorter — less to rebuild | Longer — full frontend rewrite |

---

## Backend Infrastructure Changes by Path

### Path A — Hotwire (minimal changes)

- `HomeController#table` action is **replaced** — DataTables SSP protocol removed, replaced with a standard action rendering a `_table.html.erb` partial
- `HomeController#map` stays as-is (already built)
- `StatsController#show` gains an HTML render path (currently JSON only)
- `PublicWaterSystemsController#index` and `#show` remain unused by the frontend — can be kept as a future API surface or removed

**Net change:** Simplification. Less backend code, not more.

### Path B — React SPA (significant changes)

- `HomeController` is reduced to a single action serving the HTML shell — no data logic
- `PublicWaterSystemsController#index` becomes the primary data endpoint — needs `per_page`, `fields`, and sorting to be production-ready
- `HomeController#table` is **removed** — DataTables SSP protocol gone
- All controllers that render HTML fragments (stats, report) gain JSON render paths or are replaced
- API versioning and authentication may become relevant (`/api/v1/...`)
- CORS configuration required if frontend is served from a different origin

**Net change:** The backend becomes a conventional JSON API. More work upfront, cleaner long-term separation.

---

## What Stays the Same Either Way

- **Mapbox GL JS** — always fully client-side, not affected by this decision
- **`Filterable` concern** — server-side filter logic is the same regardless of how results are delivered
- **ETL pipeline** — completely unaffected
- **PostGIS vector tiles** — `TilesController` is unchanged either way
- **The data model** — no schema changes implied by either path

---

## Hotwire Is the Right Choice If...

- The frontend is only ever for this one app (no design system needed across products)
- The team is primarily Rails developers
- Shipping quickly matters more than frontend flexibility
- The table/filter/map interaction is the full scope of UI complexity
- You're comfortable with the TODO.md modernization path (DataTables → Turbo Frame)

## React Is the Right Choice If...

- A shared design system is needed (reusable components across multiple tools or products)
- The team has or is hiring dedicated frontend engineers
- The UI will grow significantly in interactive complexity (histograms, charts, rich filtering)
- You want to use an off-the-shelf data grid with full feature support (sorting, column resizing, virtualization for large datasets)
- The app may eventually be decoupled from Rails (e.g., served as a static site with a separate API)

---

## Questions to Ask a Designer

These answers should drive the decision more than any technical preference.

**On design system:**
- Are there other tools or products at EPIC that share UI patterns with this one? Is there an intent to unify them visually?
- Do you want a component library that a designer can browse and prototype with (e.g., Storybook)?
- How much visual customization is expected beyond what off-the-shelf CSS frameworks provide?

**On the table:**
- What does the ideal table experience look like — fixed columns, resizable columns, row expansion, inline editing?
- Is the current DataTables table good enough, or is there a specific experience gap?

**On the filter UI:**
- The demographic histogram sliders (the largest remaining filter gap) require range inputs with real-time feedback. Is that still in scope? That interaction is easier in React than Stimulus.
- How many simultaneous visible filter states should the map reflect? (Currently: polygons show/hide. Future: color-coded choropleth?)

**On the map:**
- Is the choropleth (color-coded polygons by demographic value) a near-term feature? That's a significant Mapbox interaction that works in either framework but benefits from React state management.

**On users and devices:**
- What devices and screen sizes do primary users work on?
- Is there a mobile-first requirement, or is desktop the primary use case?

**On branding:**
- Is this EPIC's tool, or will it be white-labeled / embedded in other sites?
- Does EPIC have existing brand guidelines and component patterns this should conform to?

---

## Recommendation

**Default to Hotwire and finish the DataTables → Turbo Frame migration first.**

The app is 80% there. The existing Hotwire patterns (Turbo Frames for stats and reports, Stimulus for the map and filters) are working well. Completing the table modernization removes the last legacy piece and leaves the frontend clean and consistent.

Revisit this decision after the designer answers the questions above — specifically around design system scope and histogram slider complexity. If those point toward React, the backend is already close to API-ready (the `Filterable` concern, vector tiles, and ETL are all backend concerns that translate directly).
