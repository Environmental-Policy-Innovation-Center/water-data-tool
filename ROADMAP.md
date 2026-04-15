# Roadmap

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
- [ ] M6: Filter bar — filter_controller.js (submit/reset/URL sync), slider_controller.js (range inputs + histograms), full filter form markup for all filter groups, place autocomplete via PlaceSystemCrosswalk {depends: M3, M4} *(partially started: filter_controller.js + filter_state.js module + filter menu markup landed; reset/URL sync and slider histograms remain)*
- [ ] M7: Results table — table_controller.js (pagination + column sorting), table markup, stats bar (total count + summary stats), Turbo Frame wiring {depends: M3, M4} — Note: use `@pagy` instance variable (not local) so views can call `@pagy.series_nav` and other Pagy nav helpers *(partially started: HomeController#table endpoint with DataTables SSP, table_controller.js + table markup landed; stats bar remains)*
- [ ] M8: PWS detail panel + printable report — detail panel markup (demographics, EJ scores, violations, funding, watershed hazard, boil water, trend data), ReportsController printable view {depends: M3, M4}
- [ ] M9: Data exports — export_controller.js (CSV + GeoJSON with progress indicator), wired to export endpoint, respects active filters {depends: M3, M7}
- [ ] M10: Map ↔ filter/table integration — map_controller subscribes to Turbo frame load events, syncs visible features with table results, URL state management, end-to-end flow polish {depends: M5, M6, M7}
- [ ] M11: ETL ↔ tile cache invalidation — post-ETL TileCache bust, TileCacheWarmJob for common tiles after import {depends: M1, M2}
- [ ] M12: Bulk downloads page — DownloadsController + view, lists pre-packaged state/national zip files (GeoJSON + CSVs) served from S3; not filter-respecting — static data only. ETL generates and uploads the zips; this milestone wires the downloads page UI. Reference: `scratch/CO - unzipped/` for expected zip contents. {depends: M1, M4}
- [ ] M13: Kamal deploy config — Dockerfile, deploy.yml, secret management strategy, health check endpoint, production ENV documentation {depends: M4}
