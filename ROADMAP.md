# Roadmap

> **TODO:** Temporary documentation — delete once the rewrite is wrapped up.

## Drinking Water Explorer — Full App

The data model layer is complete (schema, models, Filterable concern, factories, specs, seed data).
Everything below represents what remains to build an end-to-end working product.

M1–M4 are fully independent and can be worked in parallel across two people.

### Suggested team split
- **Person A (data/backend):** M1 → M2 → M11 → M3
- **Person B (frontend/infra):** M4 → M8 → M12, then M6/M7/M9/M10 once M3 lands

---

- [x] M1: ETL pipeline — S3 manifest fetch, diff/download, type casting, staging→swap transaction, post-import spatial processing (geom repair, centroids, state joins, crosswalk build, index rebuild), DataImport records, SolidQueue recurring.yml, rake tasks, specs
- [x] M2: Vector tile endpoint — TilesController, PostGIS ST_AsMVT, TileCache read/write, 5 layers (pws/pws_points/places/counties/states), zoom-dependent simplification tolerances, param validation, specs
- [x] M3: PWS API — routes, PublicWaterSystemsController index/show/export, all ~50 filter params wired to Filterable#apply_filters, pagination/sorting, JSON serialization with all associations, CSV + gzipped GeoJSON export, specs
- [x] M4: Core UI scaffolding — application layout + nav, Tailwind config, importmap Stimulus entries, Turbo Frame region shells (filter bar, stats bar, table, detail panel), placeholder Stimulus controller stubs
- [x] M5: Map UI — map_controller.js, Mapbox GL JS v3, tile layer wiring to /tiles, popups, click-to-detail handler, layer styling for all 5 layers {depends: M2, M4} *(note: detail panel click targets /public_water_systems/:pwsid which requires M3)*
- [x] M6: Filter bar — filter_controller.js (submit/reset/URL sync), place autocomplete via PlaceSystemCrosswalk, deselect-all toggle, population size toggles, geocoder zoom handler {depends: M3, M4} *(slider histograms deferred — existing select dropdowns are functional)*
- [x] M7: Results table — table_controller.js (pagination + column sorting), table markup, stats bar (total count + summary stats), Turbo Frame wiring {depends: M3, M4} — Note: use `@pagy` instance variable (not local) so views can call `@pagy.series_nav` and other Pagy nav helpers *(partially started: HomeController#table endpoint with DataTables SSP, table_controller.js + table markup landed; stats bar remains)*
- [x] M8: PWS detail panel + printable report — Mapbox click popup with system info + "View Full Report" link, ReportsController with Turbo Frame overlay, 8 shared section partials, report_controller.js for overlay toggle {depends: M3, M4}
- [x] M9: Data exports — export_controller.js (CSV + GeoJSON), wired to export endpoint, respects active filters {depends: M3, M7} *(progress indicator deferred to TODO — test with large datasets first to determine if one is needed)*
- [x] M10: Map ↔ filter integration — when filters are applied, map_controller hides non-matching PWS polygons (pws/pws_outline/pws_points layers) via Mapbox GL setFilter; resets to show all on clear; applies on page load from URL params. URL state management already done. See scratch/roadmap_m10/m10_guide.md. {depends: M5, M6, M7}
- [x] M11: ETL ↔ tile cache invalidation — TileGenerator service extraction, post-ETL TileCache bust after any successful import, TileCacheWarmJob (z0–z6, per-zoom fan-out) {depends: M1, M2}
- [x] M12: Bulk downloads page — DownloadsController + view, lists pre-packaged state/national zip files (GeoJSON + CSVs) served from S3; not filter-respecting — static data only. ETL generates and uploads the zips; this milestone wires the downloads page UI. Reference: `scratch/CO - unzipped/` for expected zip contents. {depends: M1, M4}
- [ ] M13: AWS ECS deploy config — Dockerfile, GitHub Actions deploy workflows, secret management strategy, health check endpoint, production ENV documentation {depends: M4}
- [x] M14: Datasets catalog page — populate the existing `#container-datasets` placeholder with the 27-source dataset inventory from the legacy app (`deprecated/inc-datasets.php`). Each card shows title, description, data source link, last-updated date, update frequency, and caveats. Port the filter (by source, by frequency) and sort (by date) UI. Static editorial content, no DB queries. {depends: M4}
