# Preview ETL Reliability & Data-Freshness — Implementation Notes

_Working implementation doc. **[COREY]** = app/workflow work; **[LUKE]** = infra work (the `service_builder` / Terraform repo that owns the ECS task definitions). Consolidates the still-open items from the retired `ETL_DEPLOY_INVESTIGATION.md` and `TIGER_ETL_SOURCE_MIGRATION.md`._

## TL;DR

- Preview's nightly ETL is unreliable and likely OOMs on a first full seed. Move it to a GitHub-cron-triggered **dedicated ECS task** (reuse `run-etl-preview.yml`) instead of the in-puma scheduler.
- The cartographic job bumps the public "Latest data update" timestamp even when nothing changed. Fix by running it through the **same per-file freshness gate as every other importer**.

## TODO

_On completion, replace the owner tag with `[x]` (e.g. `- [x]: A1 …`)._

### A. Preview nightly ETL reliability

- [COREY]: A1 — Add a `schedule:` cron trigger to `.github/workflows/run-etl-preview.yml` (fires from `main`; runs one dedicated ECS task against the preview DB).
- [COREY]: A2 — Remove `ETL_SCHEDULE_ENABLED=true` from the preview env block in `deploy-client-aws.yml` so the nightly is owned solely by the cron in A1.
- [LUKE]: A3 — Verify the nightly cron's permissions. No new IAM is needed — `RunTask`/`PassRole`/secrets already work, proven by `refresh-cartographic-boundaries.yml` — but scheduled runs execute in `main`'s context, so two gates must hold:
  1. The `pr-previews` GitHub Environment deployment-branch policy must allow `main` (most likely toggle needed).
  2. The OIDC trust on `AWS_PR_DEPLOY_ROLE_ARN` must accept the environment-based `sub` (`repo:<org>/<repo>:environment:pr-previews`) — already true for the manual dispatch, so this passes unless the trust is scoped to PR refs.

  The manual workflow needs nothing new; it only had to reach `main` to be dispatchable.
- [LUKE]: A4 — Confirm OOM vs. scheduler-never-fired for the missed nightly — check CloudWatch for the preview service around 12am ET (did `epa_sabs` record a row but `epa_sabs_geoms` not?).

### B. Cartographic job & the "Latest data update" timestamp

- [COREY]: B1 — Run the cartographic load through the **same freshness gate as `FileImporter`**: check each TIGER source zip's S3 `Last-Modified`, reload only changed layers, and record a `DataImport` **only on a real change**. Today `CartographicBoundaries` sits off the `FileImporter` path (it's an `ogr2ogr` shapefile loader, not a `parse`/`import!` row importer), so it never inherited `needs_import?` — it reloads and calls `record_import` on every run, which is the false timestamp bump. Reusing the gate fixes that **and** makes the job self-triggering on a TIGER update (no separate "watcher" needed): invoke it each ETL cycle and it no-ops unless a source changed.
- [COREY]: B2 — `loaded?` remnant cleanup: the guard is gone from `post_import_steps.rb` (bare `.load`), but the dead method remains at `cartographic_boundaries.rb:44`, kept alive only by specs. Delete the method + `cartographic_boundaries_spec.rb:24–34` + the 3 stale stubs in `post_import_steps_spec.rb` (197/344/367).

### C. Environment & infra config

- [LUKE]: C1 — Confirm each env's `ETL_SOURCE_URL` points at the correct S3 folder (staging → `…/staging`, prod → `…/prod`). If prod imports the staging folder, fix it in the prod task def.

### D. Documentation

- [COREY]: D1 — Add a **deployed-environment architecture diagram** (Mermaid, here or in `DEPLOYMENTS.md`): cluster → services → instances → the three RDS databases, labelling which pieces live in app vs infra.
- [COREY]: D2 — When A–B land, fold the decisions into the ETL-preview PR and `DEPLOYMENTS.md`, then retire this doc.

## Confirmed mechanics (reference)

- **Cartographic writes a `DataImport` row unconditionally** _(Confirmed)_ — `CartographicBoundaries#record_import` (`file_url: "cartographic-boundaries"`) runs on every load and bumps the public timestamp. This is the bug B1 addresses. The tile refresh is driven separately by `ImportResult(full_refresh_required: true)`.
- **Preview is its own ECS service** _(Confirmed)_ — each PR preview is a separate service (`water_data_tool_pr_<N>`) with its own `t3.small` on the shared cluster `ep_core__dev_us-east-1`, borrowing the staging task definition. It does not run inside staging. The three RDS databases (`_production` / `_staging` / `_preview`) are separate; preview is seeded independently via ETL, and its DB is shared across open PRs.
- **The in-puma scheduler is unreliable on preview** _(Confirmed)_ — `SOLID_QUEUE_IN_PUMA=true` schedules the nightly in-process, but the single ephemeral instance may be down/redeploying at 12am ET and SolidQueue does not backfill missed runs. Staging/prod are reliable only because their services are always-on.
- **A dedicated task avoids the OOM** _(Pretty sure)_ — running ETL as its own ECS task removes the in-puma coupling; geoms streams with bounded memory, and the task inherits staging's proven memory. Residual risk is task placement/capacity (a clear `run-task` error, not a silent kill).
- **Root cause of preview not updating** _(Pretty sure)_ — preview was likely never fully seeded, so all 13 files looked new → the nightly attempted a full heavy import in-puma on 1700 MB → OOM → nothing recorded. Staging/prod only did a 2-file delta.

---

> **Cleanup:** Delete this file when A–D are resolved. Reference the closing PR in the commit message.
