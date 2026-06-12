# ETL & Deploy Investigation

## Context

### What
Discovery work from June 2026 investigating 504 errors and ECS task failures observed during
an ETL run triggered by a manually-touched S3 file (`epa_sabs_geoms.geojson`).

### Why
The errors surfaced questions about the stability of the deploy pipeline and the ETL process.
This document maps the ECS ecosystem, identifies root causes, and defines the work needed to
harden the pipeline. Audience: any team member picking up this work.

---

## Discovery

### ECS Ecosystem Map

```
Cluster: ep_core__dev_us-east-1  (single cluster — all environments live here)
│
├── ep_app__water_data_tool__dev_us-east-1          → prod-latest      = PRODUCTION ✓
├── ep_app__water_data_tool_staging__dev_us-east-1  → staging-latest   = STAGING ✓
├── ep_app__water_data_tool_pr_N__dev_us-east-1     → pr-N-<sha>       = PR previews ✓
└── ep_app__dw_dashboard__dev_us-east-1             → :latest (missing) = ORPHAN ✗
                                                       959 failed / 0 completed
                                                       Has never served a request

ECR repos:
  ep_app_service_water_data_tool  ← pipeline pushes here (active)
  ep_app_service_dw_dashboard     ← nothing pushes here (dead)
```

Note: `dev` in the cluster and service names is the EPIC infrastructure tier label for the AWS
account — not an indicator that the service is non-production. Production lives here alongside
staging and PR previews.

The deploy pipeline pushes these tags — `:latest` is never among them:

| Workflow | Tags pushed |
|---|---|
| `deploy-to-staging.yml` | `staging-<sha>`, `staging-latest` |
| `promote-to-production.yml` | `prod-latest`, `prod-promoted-<digest>` |
| `deploy-client-aws.yml` (PRs) | `pr-N-<sha>`, `pr-N-latest` |

### What We Know (High Confidence)

**Production is healthy.** Running `prod-latest`, task is up.

**The `dw_dashboard` service is orphaned.** The app was renamed from `dw_dashboard` →
`water_data_tool` at some point. The old ECS service and ECR repo were never cleaned up.
No pipeline has ever pushed to `ep_app_service_dw_dashboard`. It has never once started
successfully. The errors visible in ECS logs predate the ETL run — they were already there
and were found incidentally during this investigation.

**`REINDEX INDEX` without `CONCURRENTLY` causes real downtime.** It takes an `ACCESS EXCLUSIVE`
lock on `service_area_geometries` — every map tile request and spatial filter blocks completely
until the reindex finishes. Requests exceeding the load balancer timeout (30–60 s) return 504s.
This is the direct cause of the 504s observed during the ETL run.

**Two code bugs exist in `post_import_steps.rb`:**

1. `CartographicBoundaries.loaded?` guard prevents TIGER shapefile data from refreshing when
   a new year's files are uploaded to S3. The outer `imported_files.include?("epa_sabs_geoms")`
   check already correctly gates this block — the guard adds nothing and actively breaks
   yearly TIGER updates.

2. `bust_tile_cache` + `TileCacheWarmJob` fire before geometry enrichment completes. The warm
   job may cache incomplete data, and every tile request during the 35–105 min enrichment window
   is a cache miss on an already-loaded database.

### What We Think We Know (Lower Confidence)

**The ETL may not have completed.** The container runs at 1700 MB. `ogr2ogr` (run 3× for
TIGER shapefiles) is the most plausible OOM vector — it runs as a child process but counts
against the container memory limit. If the container was OOM-killed mid-run, geometry data
may be partially imported or rolled back. Unconfirmed — no container crash logs were available.

**The `dw_dashboard` service is safe to delete.** Evidence is strong (0 successful tasks,
dead ECR repo, no pipeline reference), but the EPIC infra team created this infrastructure
and should confirm before deletion.

### What We Need to Find Out

| Question | Who | Why it matters |
|---|---|---|
| Did the ETL complete? | Query `data_imports` (see below) | Determines if a re-run is needed |
| Is `ep_app__dw_dashboard` safe to delete? | EPIC infra team | Can't clean up without confirmation |
| S3 paths for the 3 TIGER zip files? | EPIC data team | Required for `CartographicBoundaries::LAYERS` migration |
| Can container RAM be bumped 1700 → 2048 MB? | EPIC infra team | Defensive fix for potential OOM during ETL |

**Verify ETL completion:**

```sql
SELECT file_url, imported_at
FROM data_imports
WHERE file_url LIKE '%epa_sabs_geoms%'
ORDER BY imported_at DESC
LIMIT 1;
```

If `imported_at` is recent — ETL completed. If not — re-run by touching the S3 file or forcing
via the Rails console.

---

## Implementation

### Priority 1 — Pipeline Stability

```
1. VERIFY ETL COMPLETED
   └── Query data_imports for a recent epa_sabs_geoms record
       ├── Found, recent → ETL completed ✓, proceed
       └── Not found → re-run: touch the S3 file or force via console

2. CODE PR: two fixes in post_import_steps.rb
   ├── REINDEX INDEX → REINDEX INDEX CONCURRENTLY
   │   Eliminates 504s. Users see old index until new one is ready.
   │   No data integrity risk. ~2× slower build (adds ~5–10 min to ETL).
   └── Remove CartographicBoundaries.loaded? guard
       Ensures TIGER data refreshes when new yearly files are uploaded.
       Without this fix, the next TIGER year update will silently do nothing.

3. INFRA — coordinate with EPIC team
   ├── Confirm ep_app__dw_dashboard is safe to delete
   │   └── Delete ECS service + ep_app_service_dw_dashboard ECR repo
   └── Bump container RAM 1700 → 2048 MB in staging + prod task definitions
```

### Priority 2 — Optimizations

```
4. CODE PR: move bust_tile_cache + TileCacheWarmJob
   └── Move both calls to after build_place_crosswalks in post_import_steps.rb
       Keeps stale-but-complete tiles serving fast throughout ETL;
       only triggers cache transition when data is actually ready.

5. CODE PR: migrate CartographicBoundaries::LAYERS to S3 URLs
   └── BLOCKED on EPIC data team confirming S3 paths for 3 TIGER zip files.
       See TIGER_ETL_SOURCE_MIGRATION.md for full plan and checklist.

6. CONFIG: dedicated :etl queue
   └── Add ETL worker block to config/queue.yml so the 35–105 min ETL job
       doesn't compete with user-facing background work on the default queue.
```

---

## Reference Docs

- `docs/ETL.md` — pipeline overview, runtime estimates, 504 root cause, known issues table
- `TIGER_ETL_SOURCE_MIGRATION.md` — full TIGER S3 migration plan and split checklist
- `docs/DEPLOYMENTS.md` — deploy pipeline overview

---

> **Cleanup:** Delete this file when all Priority 1 and Priority 2 items are resolved. Reference the closing PR in the commit message.
