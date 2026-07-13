# Preview ETL Reliability & Data-Freshness — Implementation Notes

_Working implementation doc. **[COREY]** = app/workflow work; **[LUKE]** = infra work (the `service_builder` / Terraform repo that owns the ECS task definitions). Consolidates the still-open items from the retired `ETL_DEPLOY_INVESTIGATION.md` and `TIGER_ETL_SOURCE_MIGRATION.md`._

## TL;DR

- Preview's nightly ETL is unreliable and likely OOMs on a first full seed. Move it to the shared always-on worker pool instead of the in-puma scheduler or a GitHub cron.
- The cartographic job bumps the public "Latest data update" timestamp even when nothing changed. Fix by running it through the **same per-file freshness gate as every other importer**.

## TODO

_On completion, replace the owner tag with `[x]` (e.g. `- [x]: A1 …`)._

### A. Preview nightly ETL reliability

- [x]: A1 — Remove the `schedule:` cron trigger from `.github/workflows/run-etl-preview.yml`; keep it manual-only as **Refresh Preview Database**.
- [x]: A2 — Remove `ETL_SCHEDULE_ENABLED=true` from preview web env and set preview web queue role to `SOLID_QUEUE_ROLE=web`, so nightly ETL is owned by the persistent preview worker.
- [LUKE]: A3 — Add the persistent preview worker service on the shared worker pool. It should connect to the shared preview DB, read from the staging S3 source, set `SOLID_QUEUE_ROLE=worker`, set `ETL_SCHEDULE_ENABLED=true`, and use `ETL_SCHEDULE=every day at 3am America/New_York`.
- [LUKE]: A4 — Confirm OOM vs. scheduler-never-fired for the missed nightly — check CloudWatch for the preview service around 12am ET (did `epa_sabs` record a row but `epa_sabs_geoms` not?).

### B. Cartographic job & the "Latest data update" timestamp

- [x]: B1 — Cartographic load is now freshness-gated, self-triggering, and layer-selective. `CartographicBoundaries.load(force:)` HEADs each of the three TIGER zips and reloads **only the layers whose source is newer** than the last import, recording a `DataImport` only when something reloaded — a no-op records nothing, killing the false timestamp bump. `Etl::Importer` invokes it as a peer step every cycle (gated), so a TIGER change is picked up without a geometry import. The result carries `changed_boundary_layers`; `PostImportSteps` re-runs only that layer's join (`assign_state_codes`/`build_place_crosswalks`) and busts+warms **only that layer's tiles** — the pws selective cache and the full-refresh path are untouched. The manual `refresh-cartographic-boundaries.yml` exposes a `force` dispatch input (default on) that maps straight to `CartographicBoundaries.load(force:)`.
- [x]: B2 — `loaded?` remnant cleanup: the guard is gone from `post_import_steps.rb` (bare `.load`), but the dead method remains at `cartographic_boundaries.rb:44`, kept alive only by specs. Delete the method + `cartographic_boundaries_spec.rb:24–34` + the 3 stale stubs in `post_import_steps_spec.rb` (197/344/367).

### C. Environment & infra config

- [LUKE]: C1 — Confirm each env's `ETL_SOURCE_URL` points at the correct S3 folder (staging → `…/staging`, prod → `…/prod`). If prod imports the staging folder, fix it in the prod task def.

### D. Documentation

- [COREY]: D1 — Add a **deployed-environment architecture diagram** (Mermaid, here or in `DEPLOYMENTS.md`): cluster → services → instances → the three RDS databases, labelling which pieces live in app vs infra.
- [COREY]: D2 — When A–B land, fold the decisions into the ETL-preview PR and `DEPLOYMENTS.md`, then retire this doc.

## Confirmed mechanics (reference)

- **Cartographic is freshness-gated and layer-selective** _(Confirmed — B1 done)_ — `CartographicBoundaries.load` reloads only the changed layer(s) and records a `DataImport` (`file_url: "cartographic-boundaries"`) only when something reloaded, so an unchanged run no longer bumps the public timestamp. The result carries `changed_boundary_layers`, which `PostImportSteps` uses to re-run only that layer's join and bust/warm only that layer's tiles — no full-cache bust.
- **Preview is its own ECS service** _(Confirmed)_ — each PR preview is a separate service (`water_data_tool_pr_<N>`) with its own `t3.small` on the shared cluster `ep_core__dev_us-east-1`, borrowing the staging task definition. It does not run inside staging. The three RDS databases (`_production` / `_staging` / `_preview`) are separate; preview is seeded independently via ETL, and its DB is shared across open PRs.
- **The in-puma scheduler is unreliable on preview** _(Confirmed)_ — `SOLID_QUEUE_IN_PUMA=true` schedules the nightly in-process, but the single ephemeral instance may be down/redeploying at 12am ET and SolidQueue does not backfill missed runs. Staging/prod were more reliable only because their services are always-on.
- **The shared worker pool isolates ETL from web health checks** _(Expected)_ — worker services run `bin/jobs start` with `SOLID_QUEUE_ROLE=worker`; web services use `SOLID_QUEUE_ROLE=web` and exclude `etl`, `tile_refresh`, and `tile_warm`.
- **Root cause of preview not updating** _(Pretty sure)_ — preview was likely never fully seeded, so all 13 files looked new, then the nightly attempted a full heavy import in-puma on 1700 MB, OOMed, and recorded nothing. Staging/prod only did a 2-file delta.

---

> **Cleanup:** Delete this file when A–D are resolved. Reference the closing PR in the commit message.
