# Runbook

Operational procedures for running and maintaining this app: the manual GitHub Actions workflows and the rake tasks used to deploy, promote, seed, refresh data, and manage preview environments.

- Deploy architecture & environments → [DEPLOYMENTS.md](DEPLOYMENTS.md)
- ETL internals (freshness gate, tiles, cartographic boundaries) → [ETL.md](ETL.md)

---

## Manual GitHub Actions workflows

Run these from the repo's **Actions** tab (each is `workflow_dispatch`). Files live in `.github/workflows/`.

### Deploy & promote

| Workflow | What it does | Inputs |
|---|---|---|
| `deploy-to-staging.yml` | Deploy `main` to staging. Runs **automatically** after CI passes on `main`; can also be dispatched manually to re-deploy. | none |
| `promote-to-production.yml` | Promote the current staging build to production. | `confirm` — type `promote` |

### Data / ETL

| Workflow | What it does | Inputs |
|---|---|---|
| `run-etl-preview.yml` | Run the ETL against the shared preview DB as a manual one-off ECS task. Nightly preview ETL is owned by the persistent preview worker service. | `table` — single file key, blank = full run · `force` — re-import ignoring `Last-Modified` |
| `refresh-cartographic-boundaries.yml` | Reload the Census TIGER boundary tables and refresh their tiles. | `target_environment` (staging/production/preview) · `scale_service_down` · `force` (default on; off = freshness-gated) · `confirm` (typed phrase) |

### Tile cache

See [TILE_CACHE.md](TILE_CACHE.md) for why/when these are needed — in short, automatic refresh only fires from ETL data changes, never from a code change to what a tile embeds.

| Workflow | What it does | Inputs |
|---|---|---|
| `bust-tile-cache.yml` | Delete cached `tile_cache` rows for the given layers in one environment. Run after a code change alters what a tile embeds (e.g. new attributes) — existing cached tiles otherwise keep serving the old shape indefinitely. | `target_environment` (staging/production/preview) · `layers` (comma-separated `tile_cache.layer` values, default `pws,pws_low_poly_v1`) · `scale_service_down` · `confirm` (typed phrase) |
| `warm-tile-cache.yml` | Pre-generate and cache map tiles for the given layers/zoom range, so the first real visitor after a bust doesn't pay the live-generation cost. Safe to re-run. | `target_environment` (staging/production/preview) · `layers` (comma-separated logical layers, blank = all) · `max_zoom` (default 8) · `scale_service_down` · `confirm` (typed phrase) |

### Preview environment management

| Workflow | What it does | Inputs |
|---|---|---|
| `list-pr-environments.yml` | List active PR preview environments. | none |
| `teardown-pr-env.yml` | Destroy one PR's preview environment. | `pr_number` · `confirm` = `teardown` |
| `teardown-stale-pr-envs.yml` | Destroy preview envs with no new commits in N days. | `days_old` (default 14) · `confirm` = `teardown` |

---

## Operational rake tasks

Run in the target environment with `bin/rails <task>` (or via the workflows above for deployed envs).

| Task | What it does |
|---|---|
| `etl:import[table,mode]` | Run the ETL import. Examples: `etl:import` (all changed), `etl:import[epa_sabs]` (one file), `etl:import[epa_sabs,force]` (ignore timestamps), `etl:import[cartographic-boundaries]` (boundaries only). See [ETL.md](ETL.md). |
| `etl:geometries:generalize` | Backfill precomputed low-zoom generalized geometries. |
| `db:seed:states` | Seed cartographic boundaries + state data (invoked by `db:seed`). |
| `db:seed:fake_geometries[states]` | Seed placeholder geometries for local dev. |
