# Handoff — pick up here after merging `refactor/config-simplification` → `main` and pulling

_Personal scratch doc (untracked — not for the public repo). Written 2026-07-07._

## Context (where we left off)
- `refactor/config-simplification` merged the teammate's ETL/AppConfig PR (`a058f96`, Luke). We **dropped our downloads-DRY commit `a94d79b`** (superseded by Luke's `AppConfig`) and reconciled conflicts by taking theirs. `bin/ci` green (1087 examples). Branch was force-pushed.
- Remaining work parked in **two path-scoped git stashes** (see items 2 & 3).

---

## 1. Download fix — `fix/downloads-use-existing-s3-endpoint` (off `main`) — **do first**

**Problem:** Luke's AppConfig points download links at a per-env S3 layout that doesn't exist → **403 AccessDenied on every download** (staging + local; will break prod on next deploy). This is a regression already on `main`.

**Proven facts (curl):** only `…/public-data-downloads/staged/national-dw-tool-staged.zip` returns 200. The AppConfig paths (`staging/` or `prod/` folder, `national-dw-tool.zip` filename) all 403. There is **one bucket (`tech-team-data`), one download location** — no per-env download data. `Data Dictionary.xlsx` is referenced nowhere (app or legacy) — orphan.

**Fix (4 spots):**
1. `app/services/app_config.rb` — `public_downloads_base_url` default → `"#{S3_BASE_URL}/public-data-downloads/staged"`; delete `s3_environment_folder` and `app_env` (unused).
2. `app/views/home/_downloads.html.erb:15` — `download_url("national-dw-tool-staged.zip")` (was `"national-dw-tool.zip"`). States line + methodology PDF already resolve — leave.
3. `spec/services/app_config_spec.rb` — replace the two per-env-folder examples (staging→`/staging`, production→`/prod`) with one asserting the single `/staged` default. Remove `app_env` tests.
4. `.env.example` — its `PUBLIC_DOWNLOADS_BASE_URL=…/staging` would override + re-break; correct to `…/staged` or comment it out. (This file also lives in the docs stash — reconcile.)

**Verify:** `bin/ci`; `bin/dev` → open Downloads panel → National + a state + methodology all download. `curl -sI` the generated URLs = 200.

**Flag to Luke:** this reverses his per-env-folder design. Confirm he wasn't planning to migrate the bucket to `{staging,prod}/` — user's call is single-endpoint, no migration.

---

## 2. Documentation PR — `docs/significant-cleanup-and-additions` (off `main`) - already cut
Apply stash **`d5a75359`** (`wip-docs-and-kamal-cleanup`):
```
git checkout main && git pull
git checkout -b docs/cleanup-and-kamal-removal
git stash apply d5a75359      # stage, commit, push, PR (dont commit without MY review)
```
Contents: README rewrite, ARCHITECTURE/ETL/DEPLOYMENTS/FILTERING trims, how-to guides (ADD/EDIT/REMOVE data field, FIX_BIN_CI_CHECK_FAILURES, COMMON_RAILS_COMMANDS, UPDATE_S3_TIMESTAMPS), GETTING_STARTED, BENCHMARKING, Kamal removal, Mapbox-token sanitization (`deprecated/.../scripts.js`), CONTRIBUTING, ROADMAP, + the 2 merge-driven doc tweaks (ETL.md line 31, .env.example header). **Note:** the `.env.example` `PUBLIC_DOWNLOADS_BASE_URL` value here needs the item-1 correction too.

## 3. ETL preview workflow PR — `feat/etl-preview-workflow` (off `main`) - already cut
Apply stash **`5b686de5`** (`wip-preview-etl-workflow`):
```
git checkout main
git checkout -b feat/etl-preview-workflow
git stash apply 5b686de5      # stage, commit, push, PR (dont commit without MY review)
```
Contents: `.github/workflows/run-etl-preview.yml` — manual `workflow_dispatch`, runs ETL (full or single `table`) against the shared preview DB. Inputs `table` + `force`. Live `[ETL]` log streaming, 90-min timeout, no scale-down.

_Use `git stash apply` (not `pop`) so a stash survives a botched apply. After all land: `git stash drop d5a75359 && git stash drop 5b686de5`._

---

## Later backlog (unrelated — capture so it's not forgotten)
- [ ] **Rebase + fix BWN (boil-water-notice) work** — _must_
- [ ] **Match tooltips with legacy data/layout** — _must_
- [ ] **AWAI ticket pt 1** — _must_
- [ ] **AWAI ticket pt 2** — _semi-must_
- [ ] **Mobile fixes** — _semi-bonus_
- [ ] **Reports** — _bonus_
