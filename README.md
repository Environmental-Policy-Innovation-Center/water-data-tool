# Drinking Water Explorer v1.1

A public-facing data visualization tool that lets anyone explore public water systems across the United States. Filter, map, and download data about water quality, violations, demographics, and funding for ~44,000 community water systems.

Built by [EPIC](https://www.policyinnovation.org/) (Environmental Policy Innovation Center) in collaboration with [Thrive](https://thriveteam.io/) and [Bitfoot](https://bitfoot.co/).

v1.0 Developed in partnership with [Center for Neighborhood Technology](cnt.org).

Looking for the tool? See [here](https://www.policyinnovation.org/drinking-water-explorer-tool).

---

## Tech Stack

- **Backend:** Rails 8
- **Frontend:** Hotwire (Turbo + Stimulus), Tailwind CSS
- **Database:** PostgreSQL 15+ with PostGIS (via Docker by default)
- **Map:** Mapbox GL JS v3
- **Background jobs:** SolidQueue
- **Testing:** RSpec, FactoryBot, Shoulda Matchers

---

## Prerequisites

- [Ruby](https://www.ruby-lang.org/) (version specified in `.ruby-version`), installed via a version manager — [rbenv](https://github.com/rbenv/rbenv) (recommended), [RVM](https://rvm.io/), [mise](https://mise.jdx.dev/), or [asdf](https://asdf-vm.com/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) — used only to run PostgreSQL + PostGIS. Not otherwise required; any PostgreSQL 15+ with PostGIS works if you'd rather run it natively.
- [Git](https://git-scm.com/) — version control, used to clone the repo and manage changes. Often already installed; check with `git --version`.
- A [Mapbox](https://www.mapbox.com/) access token (free tier is sufficient for development)
- [GDAL](https://gdal.org/) (`ogr2ogr`) — for loading Census cartographic boundary shapefiles
  - macOS: `brew install gdal`
  - Ubuntu/Debian: `apt-get install gdal-bin`
- `ETL_SOURCE_URL` env var — the base HTTPS URL to the S3 folder containing source data files. Required to seed the database. **Provided by a project admin** (not committed to the repo); add it to your `.env` before running `bin/setup`.


## Current Deployed Instances
- **Production**: https://watertool.policyinnovation.info
- **Staging**: https://water-data-tool-staging.policyinnovation.info
- **PR previews**: https://water-data-tool-pr-\<N\>.policyinnovation.info (spun up automatically for each open PR)

---

## Quick Start

> **New to Rails?** For a from-scratch walkthrough — installing Docker, a Ruby version manager, GDAL, and the rest, with troubleshooting — see **[docs/GETTING_STARTED.md](docs/GETTING_STARTED.md)**. The steps below are the condensed version.

#### 1. Clone the repo

```bash
git clone https://github.com/epicenter/water-data-tool.git
cd water-data-tool
```

#### 2. Install Ruby dependencies

```bash
bundle install
```

#### 3. Set up environment variables

```bash
cp .env.example .env
```

Edit `.env` and fill in the required values:
- `MAPBOX_ACCESS_TOKEN` — for map rendering
- `MAPBOX_STYLE_URL` — for account-specific styling configs
   - _placeholder value: `mapbox://styles/mapbox/light-v11`_
- `ETL_SOURCE_URL` — required for the database seed step; get it from a project admin (see Prerequisites above). Both seeding and the ETL pipeline use this URL to locate source data files on S3.

See the Environment Variables section below for the full list. If you have a port conflict with a local PostgreSQL install, also set `DB_PORT`.

#### 4. Start PostgreSQL + PostGIS

The app needs PostgreSQL 15 with the PostGIS extension reachable on `localhost:5432`. Pick one:

**Option A — Docker (recommended; matches CI and production):**

```bash
docker compose up -d
```

Starts a PostGIS-enabled PostgreSQL container, preconfigured with the `postgres` / `postgres` credentials the app expects.

**Option B — Native install (Homebrew, macOS):**

```bash
brew install postgresql@15 postgis
brew services start postgresql@15
createuser -s postgres   # the app defaults to a `postgres` superuser role
```

Notes for the native path:
- Make sure the PostGIS build matches PostgreSQL 15.
- Instead of creating a `postgres` role, you can point the app at your own local role by setting `DB_USERNAME` / `DB_PASSWORD` in `.env`.
- If another PostgreSQL is already on port 5432, set a different port in `.env` (e.g. `DB_PORT=5433`) to avoid the conflict.

#### 5. Set up the app

```bash
bin/setup
```

Installs dependencies, creates and migrates the database, and seeds development data. The seed step downloads water system data from S3 (requires `ETL_SOURCE_URL`) and loads Census cartographic boundaries (requires `ogr2ogr`). This will take several minutes on first run — the national GeoJSON is large but is cached in `tmp/seeds/` for subsequent runs.

By default this seeds four states for broad filter coverage:

| State | Purpose |
|---|---|
| VT + RI | Small, fast to load; cover most common filter cases (~477 systems) |
| OH | Adds wholesaler and school/daycare systems (zero in VT/RI) |
| CO | Medium size; adds tribal systems (Ute) for tribal primacy/owner filter coverage |
| PR | Territory; covers `primacy_type = "Territory"` and `owner_type = "Territory"` filters |

```bash
bin/rails 'db:seed:states[VT,RI,OH,CO,PR]'
```

After seeding, the map is fully functional — tile generation happens on-demand. No additional setup steps are required.

#### 6. Install Git hooks (Lefthook) — recommended

The repo includes [`lefthook.yml`](lefthook.yml), which runs [Standard](https://github.com/standardrb/standard) on staged `.rb` files and [ERB Lint](https://github.com/Shopify/erb-lint) on staged `.html.erb` files before each commit. After `bundle install`, register the hooks **once per clone**:

```bash
bundle exec lefthook install
```

To replace hook scripts that are already installed (for example after a Lefthook upgrade), use `bundle exec lefthook install -f`.

You can still lint without Git hooks (see [Development workflow](#development-workflow)): check with `bin/standardrb` / `bin/erb_lint --lint-all`, or apply safe auto-fixes with `bin/standardrb --fix` / `bin/erb_lint --lint-all --autocorrect`. ERB Lint config lives in [`.erb_lint.yml`](.erb_lint.yml) at the repo root (see [Shopify erb-lint](https://github.com/Shopify/erb-lint#configuration)).

#### 7. Start the app

```bash
bin/dev
```

Visit [http://localhost:3000](http://localhost:3000)

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `MAPBOX_ACCESS_TOKEN` | Yes | Mapbox GL JS token for map rendering |
| `MAPBOX_STYLE_URL` | Yes | Mapbox Style URL for account specific styling config |
| `DB_PORT` | No | PostgreSQL port (default `5432`). Only needed if your Docker container is mapped to a non-default port to avoid a conflict with a local PostgreSQL install — see `docker-compose.override.yml`. |
| `ETL_SOURCE_URL` | Yes (setup + ETL) | Base HTTPS URL to the S3 folder containing source data files. Staging should point at the S3 `staging` folder; production should point at `prod`. No AWS credentials needed for public reads. |
| `PUBLIC_DOWNLOADS_BASE_URL` | No | Base HTTPS URL for ZIP downloads shown in the Downloads panel. Defaults to the shared S3 `public-data-downloads/staged` folder. |
| `METHODOLOGY_PDF_URL` | No | Full HTTPS URL for the methodology/documentation PDF. Defaults to the shared S3 location. |
| `ETL_SCHEDULE_ENABLED` | No | Set to `true` only in the deployment that should enqueue recurring ETL imports. Defaults to off. |
| `RAILS_ENV` | No | Defaults to `development` |

---

## Deploying

The app deploys to **AWS ECS**. There are three deploy targets — PR previews, staging, and production — all gated on the GitHub Actions **repository variable** `AWS_DEPLOY_ENABLED=true` (GitHub → Settings → Secrets and variables → Actions → Variables); forks that don't set it skip every deploy job:

- **PR preview** — opening a pull request against `main` spins up an ephemeral environment via the **"Deploy to AWS ECS"** workflow (`deploy-client-aws.yml`); it's torn down automatically when the PR closes.
- **Staging** — deployed **automatically** when a PR merges to `main` and CI passes, via the **"Deploy to Staging"** workflow (`deploy-to-staging.yml`). Can also be triggered manually.
- **Production** — deployed **manually only**, via the **"Promote Staging to Production"** workflow (`promote-to-production.yml`), which re-tags the exact image already tested on staging (no rebuild) and requires typing `promote` to confirm.

See [docs/DEPLOYMENTS.md](docs/DEPLOYMENTS.md) for the full reference — environment URLs, ECS/ECR details, triggering deploys, checking what's running, and rollback.

---

## Development Workflow

Everyday commands once you're set up — for first-time setup see [Quick Start](#quick-start) (or [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md)). Branch off `main`, and follow the branch-naming and conventional-commit conventions in [CONTRIBUTING.md](CONTRIBUTING.md).

```bash
# Start PostgreSQL (if not already running)
docker compose up -d                    # Docker
# brew services start postgresql@15     # ...or native (Homebrew)

# Start the Rails app (web server + asset watcher)
bin/dev

# Run tests
bundle exec rspec

# Run the deterministic project CI
bin/ci

# Lint (check only — same tools as Lefthook pre-commit; no Git hook required)
bin/standardrb
bin/erb_lint --lint-all

# Auto-fix what each tool can safely correct (review `git diff` afterward)
bin/standardrb --fix
bin/erb_lint --lint-all --autocorrect

# Rails console
bin/rails console

# Seed specific states for local dev. NOT the ETL pipeline — a separate, state-scoped
# loader (SeedImport) that downloads the same S3 files but maps them itself.
# Only needs ETL_SOURCE_URL.
bin/rails 'db:seed:states[VT,RI,OH,CO,PR]'

# Re-seed with fresh data from S3 (seed files are cached in tmp/seeds/ and reused by default)
rm -rf tmp/seeds/ && bin/rails 'db:seed:states[VT,RI,OH,CO,PR]'

# Run the full ETL import — the real pipeline, loading the entire national dataset
# (~44k+ public water systems). Requires ETL_SOURCE_URL. Safe to run locally for
# performance testing (exports, large filter sets, map rendering at scale).
bin/rails etl:import

# Run ETL import (single table)
bin/rails 'etl:import[epa_sabs]'

# Stop PostgreSQL
docker compose down                     # Docker
# brew services stop postgresql@15      # ...or native (Homebrew)
```

### Background jobs and tile cache refresh

**Why we cache tiles.** The map is drawn from vector tiles produced by spatial SQL. Generating them on every request would be slow, so the app caches each tile the first time it's requested: the cache **builds up as the app is used**, and any later view of an already-cached area/zoom is served instantly. When a user pans or zooms to an area that isn't cached yet, the app generates those tiles on the fly and stores them for next time.

**Keeping the cache fresh.** When new geo-related data is imported, the app refreshes only the *affected* tiles rather than clearing the whole cache. Importers report changed PWS IDs and affected map layers; `TileImpact` converts those into **z5–z8 XYZ tile coordinates**; and `TileCacheRefreshJob` overwrites only those cached rows on the `tile_refresh` queue. Existing tiles stay readable until replacements are ready. See [docs/ETL.md](docs/ETL.md) for how an import drives tile refresh.

The full `TileCacheWarmJob` still exists for explicit full-refresh or maintenance cases. In production, SolidQueue processes background jobs persistently. In development, the ETL runs as a short-lived rake task (`bin/rails etl:import`) — queued refresh/warm jobs only run automatically if a SolidQueue worker is running.

After loading the national dataset locally, you can warm the full z0–z8 cache manually if you need cold-cache performance testing:

```bash
bin/rails runner "TileCacheWarmJob.perform_now"
```

This runs in the foreground and **blocks that terminal** (not the app) until every z0–z8 tile is generated — roughly **half an hour at national scale**. Progress is logged to stdout so you can watch it advance; it's a one-time cost, and once warm the tiles are served straight from the cache.

### Local performance checks

`bin/ci` is the deterministic pre-merge baseline (if it fails, see [docs/how_to/FIX_BIN_CI_CHECK_FAILURES.md](docs/how_to/FIX_BIN_CI_CHECK_FAILURES.md)) — but it does **not** measure performance.

When a change touches map tiles, spatial SQL, or cache behavior, there are optional local benchmark scripts (e.g. `bin/rails runner bin/benchmark-tiles` for the safe tile-SQL guard). They aren't part of CI — see **[docs/BENCHMARKING.md](docs/BENCHMARKING.md)** for what each script does and when to reach for it.

---

## Configuration: filters, table columns, tooltips

The map's filters, the data-table columns, and their copy are **config-driven** — you add, remove, or edit them by editing YAML, usually without touching Ruby. Four files own it:

| File | Owns |
|------|------|
| `config/fields.yml` (the "manifest") | What each data field **is** — how it loads, and whether it's a table column, a filter, and/or a histogram. The source of truth. |
| `config/filter_layout.yml` | Which **menu / category** a filter sits in, and its order. |
| `config/table_layout.yml` | Which **columns** show in the table, their order, and column-picker group. |
| `config/tooltips.yml` | Tooltip **copy**, referenced by key from the other files. |

Most changes are YAML-only — permit args, sorting, exports, histograms, and the rendered filter menus all **derive** from these files. The main exception: ingesting a **brand-new source file** also needs a one-line entry in `app/services/etl/importer.rb` (a new DB column needs a migration too). Step-by-step guides live in **[`docs/how_to/`](docs/how_to/)**:

- [`docs/how_to/ADD_NEW_DATA_FIELD.md`](docs/how_to/ADD_NEW_DATA_FIELD.md) — add a data field / filter / column
- [`docs/how_to/EDIT_EXISTING_DATA_FIELD.md`](docs/how_to/EDIT_EXISTING_DATA_FIELD.md) — edit an existing one
- [`docs/how_to/REMOVE_EXISTING_DATA_FIELD.md`](docs/how_to/REMOVE_EXISTING_DATA_FIELD.md) — remove one

See [docs/FILTERING.md](docs/FILTERING.md) for how filtering works end-to-end.

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md) | First-time setup walkthrough — install every tool from scratch, with troubleshooting |
| [docs/API.md](docs/API.md) | Endpoint specifications — filter API, tiles, export |
| [docs/FILTERING.md](docs/FILTERING.md) | Filter system — config sources, AND/OR combining, the `data-filter-*` DOM contract |
| [docs/how_to/](docs/how_to/) | Step-by-step guides — add / edit / remove a data field, filter, or column |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Rails app structure — models, controllers, Stimulus, Turbo patterns |
| [docs/BENCHMARKING.md](docs/BENCHMARKING.md) | Optional local performance scripts — server query paths and map-tile timing |
| [docs/DEPLOYMENTS.md](docs/DEPLOYMENTS.md) | Deploy environments, how to trigger deploys, checking live state, rollback |
| [docs/DISCOVERY.md](docs/DISCOVERY.md) | Discovery notes from the legacy PHP app analysis |
| [docs/ETL.md](docs/ETL.md) | Data pipeline design — S3 to PostgreSQL import flow |
| [docs/GLOSSARY.md](docs/GLOSSARY.md) | Terminology and domain definitions |
| [docs/LOOKBOOK.md](docs/LOOKBOOK.md) | ViewComponent preview catalog — how to access and add previews |
| [docs/MAPPING.md](docs/MAPPING.md) | Mapping design information |
| [docs/RUNBOOK.md](docs/RUNBOOK.md) | Operational runbook — manual GitHub workflows and rake tasks for deploy, ETL, and preview envs |
| [docs/SCHEMA.md](docs/SCHEMA.md) | Database schema — all tables, columns, types, indexes |
| [docs/TRANSITION.md](docs/TRANSITION.md) | Migration notes from the legacy PHP app to Rails |
| [docs/open_items/](docs/open_items/) | Known issues, discovery work, and planned improvements not yet ticketed |

---

## License

MIT. See [LICENSE](LICENSE).

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
