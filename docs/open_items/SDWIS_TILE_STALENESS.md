# Map popup data silently goes stale after SDWIS data updates

## Context

### What
`sdwis_viols.csv` and the generic importer never populate `changed_pwsids` on the
`Etl::ImportResult` they return. That means a genuine, routine data change to any column those
importers write — including `phone_number`, `owner_type`, `years_operating`, and every
`violations_summaries` field (`total_violations_10yr` among them) — never triggers any automatic
tile cache refresh, selective or full.

### Why
This is a live data-correctness gap, not architecture cleanup. `epa_sabs.csv`'s custom importer
already does this correctly, so most of the `pws` layer (`pws_name`, `symbology_field`, `pop_cat_5`,
`population_served_count`, `service_connections_count`, `area_sq_miles`) is fine — a real change to
any of those columns correctly triggers `TileImpact` → `TileCacheRefreshJob` for just the affected
systems. But `phone_number`, `owner_type`, `years_operating`, and the violations fields — all four
of the fields added to the map popup in mid-2026 — come from `sdwis_viols.csv`, which reports
nothing.

In practice: SDWIS violation data updates on its own publishing schedule (new inspection results,
resolved/new violations, changed contact info). Each time the nightly ETL picks up a genuine change
there, the database is updated correctly, but the map keeps silently showing whatever was cached as
of the last *unrelated* bust — no error, no failed job, nothing that would prompt anyone to notice.
The manual `bust-tile-cache.yml` workflow (see [docs/TILE_CACHE.md](../TILE_CACHE.md)) doesn't
mitigate this in practice — it's a fine tool when a human deploying new tile-embedding *code* knows
to run it, but nobody has a signal telling them a routine *data* update now warrants a bust. Given
this app's core purpose includes showing accurate current compliance/violation status, this can
drift for an unbounded amount of time (until the next unrelated cache bust happens to reset it).

---

## Discovery

### How to tell which ETL files should trigger a tile refresh (this is the audit that found the gap)

There's no single manifest listing "these are the tile-relevant source files" — it takes a manual
cross-reference, in two steps:

1. List every column selected in `TileGenerator.layer_sql` for a given layer (currently only `pws`
   has attribute columns beyond `pwsid`/geometry: `pws_name`, `symbology_field`, `pop_cat_5`,
   `population_served_count`, `service_connections_count`, `area_sq_miles`, `phone_number`,
   `owner_type`, `years_operating`, `total_violations_10yr`).
2. For each column, trace its source. Check `config/fields.yml` for a `source:` block — present
   only for **generic**-importer-driven fields. If absent (as with `pws_name`, `owner_type`,
   `phone_number`, `years_operating` — none of these carry a `source:` block), the column is written
   by a **custom** importer instead; grep that importer's Ruby source directly
   (`app/services/etl/importers/*.rb`) to find which file/class writes it.

Applying that today: everything in the `pws` layer traces to `epa_sabs.csv`
(`Etl::Importers::EpaSabs`) except `phone_number`/`owner_type`/`years_operating`/
`total_violations_10yr`, which trace to `sdwis_viols.csv` (`Etl::Importers::SdwisViols`).

**This audit is easy today but not self-maintaining.** There's a real risk of drifting stale the
next time someone adds a new tile-embedded column without re-running this same cross-reference —
exactly the situation this PR's popup fields were in before this doc existed. Worth considering
whether a lighter-weight, enforced check (e.g. a spec that asserts every `TileGenerator.layer_sql`
column has a traceable, `changed_pwsids`-reporting source) would be worth the cost, versus relying
on this doc's existence as the reminder.

### The fix, in outline

Apply the same pattern `Etl::Importers::EpaSabs#changed_pwsids_for` already uses (see
`app/services/etl/importers/epa_sabs.rb:52-61`) to `Etl::Importers::SdwisViols`: before upserting,
load the existing `PublicWaterSystem`/`ViolationsSummary` rows for the incoming pwsids, compare each
tile-relevant field against the freshly parsed row, and collect any pwsid that's new or differs.
Two things make this slightly more involved than `EpaSabs`'s version:

- `SdwisViols#import!` writes to **two models** (`PublicWaterSystem` and `ViolationsSummary`) from
  one file — the diff needs to check both, not just one `MAP_FIELDS`-style list against one model.
- Whether to extend this to `Etl::Importers::Generic` too depends on whether any *currently*
  tile-embedded column is ever sourced through the generic path — as of this writing, none are
  (everything generic-importer-driven that's tile-relevant is already covered via `epa_sabs.csv`),
  but that could change if a future tile column comes from a generic-importer file.

## Implementation Guide

Not yet scoped into concrete steps — this is Discovery-stage. Whoever picks this up should:

1. Confirm the current column/file mapping above is still accurate (re-run the audit — it may have
   drifted since this doc was written).
2. Extend `Etl::Importers::SdwisViols#import!` to compute `changed_pwsids` across both models it
   writes, mirroring `EpaSabs#changed_pwsids_for`.
3. Add spec coverage asserting a changed `phone_number`/`owner_type`/`years_operating`/violations
   value produces a non-empty `changed_pwsids`, and an unchanged reimport produces an empty one.
4. Confirm `TileImpact`/`TileCacheRefreshJob` actually fire end-to-end for a real `sdwis_viols.csv`
   re-import with a changed row.

---

> **Cleanup:** Delete this file when resolved. Reference the closing PR in the commit message.
