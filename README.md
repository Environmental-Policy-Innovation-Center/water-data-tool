# Drinking Water Explorer v1.1

A public-facing data visualization tool that lets anyone explore public water systems across the United States. Filter, map, and download data about water quality, violations, demographics, and funding for ~44,000 community water systems.

Built by [EPIC](https://www.policyinnovation.org/) (Environmental Policy Innovation Center) in collaboration with [Thrive](https://thriveteam.io/) and [Bitfoot](https://bitfoot.co/).

v1.0 Developed in partnership with [Center for Neighborhood Technology](cnt.org).

Looking for the tool? See [here](https://www.policyinnovation.org/drinking-water-explorer-tool).

---

## Tech Stack

- **Backend:** Rails 8
- **Frontend:** Hotwire (Turbo + Stimulus), Tailwind CSS
- **Database:** PostgreSQL 15+ with PostGIS (runs in Docker)
- **Map:** Mapbox GL JS v3
- **Background jobs:** SolidQueue
- **Testing:** RSpec, FactoryBot, Shoulda Matchers

---

## Prerequisites

- [Ruby](https://www.ruby-lang.org/) (version specified in `.ruby-version`) — we recommend [mise](https://mise.jdx.dev/) or [asdf](https://asdf-vm.com/) to manage Ruby versions
- [Node.js](https://nodejs.org/) (for asset compilation)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (for PostgreSQL + PostGIS)
- [Git](https://git-scm.com/)
- A [Mapbox](https://www.mapbox.com/) access token (free tier is sufficient for development)
- [GDAL](https://gdal.org/) (`ogr2ogr`) — for loading Census cartographic boundary shapefiles
  - macOS: `brew install gdal`
  - Ubuntu/Debian: `apt-get install gdal-bin`
- `ETL_SOURCE_URL` env var — the base HTTPS URL to the S3 folder containing source data files. Required to seed the database. Get this value from the project team and add it to your `.env` before running `bin/setup`.


## Current Deployed Instances
- **Production**: https://watertool.policyinnovation.info
- **Staging**: https://water-data-tool-staging.policyinnovation.info
- **PR previews**: https://water-data-tool-pr-\<N\>.policyinnovation.info (spun up automatically for each open PR)

---

## Quick Start

1. **Clone the repo**

   ```bash
   git clone https://github.com/epicenter/water-data-tool.git
   cd water-data-tool
   ```

   If you are working from a transferred/forked repository, use your own Git remote URL.

2. **Install Ruby dependencies**

   ```bash
   bundle install
   ```

3. **Set up environment variables**

   ```bash
   cp .env.example .env
   ```

   Edit `.env` and fill in the required values:
   - `MAPBOX_ACCESS_TOKEN` — for map rendering
   - `MAPBOX_STYLE_URL` — for account specific styling configs
      - _placeholder value: `mapbox://styles/mapbox/light-v11Mapbox`_ 
   - `ETL_SOURCE_URL` — required for the database seed step. Both seeding and the ETL pipeline use this URL to locate source data files on S3 (see Prerequisites above)

   See the Environment Variables section below for the full list. If you have a port conflict with a local PostgreSQL install, also set `DB_PORT`.

4. **Start PostgreSQL**

   ```bash
   docker compose up -d
   ```

   This starts a PostGIS-enabled PostgreSQL container. The database runs on `localhost:5432`.

5. **Set up the app**

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

   To seed only the small states (faster, still useful for most work):
   ```bash
   bin/rails 'db:seed:states[VT,RI]'
   ```

   After seeding, the map is fully functional — tile generation happens on-demand. No additional setup steps are required.

6. **Install Git hooks (Lefthook)** (recommended)

   The repo includes [`lefthook.yml`](lefthook.yml), which runs [Standard](https://github.com/standardrb/standard) on staged `.rb` files and [ERB Lint](https://github.com/Shopify/erb-lint) on staged `.html.erb` files before each commit. After `bundle install`, register the hooks **once per clone**:

   ```bash
   bundle exec lefthook install
   ```

   To replace hook scripts that are already installed (for example after a Lefthook upgrade), use `bundle exec lefthook install -f`.

   You can still lint without Git hooks (see [Development workflow](#development-workflow)): check with `bin/standardrb` / `bin/erb_lint --lint-all`, or apply safe auto-fixes with `bin/standardrb --fix` / `bin/erb_lint --lint-all --autocorrect`. ERB Lint config lives in [`.erb_lint.yml`](.erb_lint.yml) at the repo root (see [Shopify erb-lint](https://github.com/Shopify/erb-lint#configuration)).

7. **Start the app**

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
| `SOLID_QUEUE_ROLE` | No | `web` processes only lightweight web queues; `worker` processes ETL and tile queues. Defaults to `web`. |
| `ETL_SCHEDULE_ENABLED` | No | Set to `true` only on dedicated worker services that should enqueue recurring ETL imports. Defaults to off. |
| `ETL_SCHEDULE` | No | Optional Solid Queue recurring schedule string for worker services. Defaults to `every day at 12am America/New_York`. |
| `RAILS_ENV` | No | Defaults to `development` |

---

## Deploying

### Kamal (portable, single host)

The app ships with [Kamal](https://kamal-deploy.org/) as a portable self-hosting option. Configuration lives in `config/deploy.yml` and `.kamal/secrets`. Refer to the Kamal docs and the `config/deploy.yml` comments for setup.

### AWS ECS (EPIC production deployment)

The EPIC production, staging, and per-PR preview environments run on AWS ECS, deployed via `.github/workflows/deploy-client-aws.yml`. The workflow is gated on `AWS_DEPLOY_ENABLED=true` — forks and other deployments that don't set this variable will see the job silently skipped.

See [docs/DEPLOYMENTS.md](docs/DEPLOYMENTS.md) for the full reference: environment URLs, how to trigger deploys, how to check what's running, and rollback procedures.

---

## Development Workflow

```bash
# Start PostgreSQL (if not already running)
docker compose up -d

# Start the Rails app (web server + asset watcher)
bin/dev

# Run tests
bundle exec rspec

# Run the deterministic project CI
bin/ci

# Optional local pre-merge tile performance guard
bin/rails runner bin/benchmark-tiles

# Lint (check only — same tools as Lefthook pre-commit; no Git hook required)
bin/standardrb
bin/erb_lint --lint-all

# Auto-fix what each tool can safely correct (review `git diff` afterward)
bin/standardrb --fix
bin/erb_lint --lint-all --autocorrect

# Rails console
bin/rails console

# Seed specific states (downloads from S3 via HTTPS — only needs ETL_SOURCE_URL)
bin/rails 'db:seed:states[VT,RI,OH,CO,PR]'

# Re-seed with fresh data from S3 (seed files are cached in tmp/seeds/ and reused by default)
rm -rf tmp/seeds/ && bin/rails 'db:seed:states[VT,RI,OH,CO,PR]'

# Run full ETL import — loads the entire national dataset (~70k systems)
# Requires ETL_SOURCE_URL. Safe to run locally for performance testing
# (exports, large filter sets, map rendering at scale).
bin/rails etl:import

# Run ETL import (single table)
bin/rails 'etl:import[epa_sabs]'

# Stop PostgreSQL
docker compose down
```

### Background jobs and tile cache refresh

Normal ETL imports refresh cached map tiles selectively. Importers report changed PWS IDs and affected map layers, `TileImpact` converts those changes into z5-z8 XYZ tile coordinates, and `TileCacheRefreshJob` overwrites only those cached tile rows on the `tile_refresh` queue. Existing cached tiles remain readable until replacements are ready.

The full `TileCacheWarmJob` still exists for explicit full-refresh or maintenance cases and runs on the `tile_warm` queue. In production-style deployments, web services use `SOLID_QUEUE_ROLE=web` and never process `etl`, `tile_refresh`, or `tile_warm`; dedicated worker services use `SOLID_QUEUE_ROLE=worker` and run those heavy queues. In development, the ETL runs as a short-lived rake task (`bin/rails etl:import`) -- queued refresh/warm jobs only run automatically if a SolidQueue worker is running.

After loading the national dataset locally, you can warm the full z0-z8 cache manually if you need cold-cache performance testing:

```bash
bin/rails runner "TileCacheWarmJob.perform_now"
```

This blocks until all z0-z8 tiles are generated. Progress is logged to stdout.

### Local performance checks

Keep `bin/ci` as the deterministic pre-merge baseline. When a change touches map tiles, spatial SQL, or cache behavior, run the safe tile performance guard after CI:

```bash
bin/ci
bin/rails runner bin/benchmark-tiles
```

Benchmark scripts have different cache behavior:

| Script | Purpose | Cache behavior |
|---|---|---|
| `bin/benchmark` | Broad query benchmarking for filters, stats, table loads, search, and warm tile retrieval by zoom tier | Non-destructive |
| `bin/benchmark-tiles` | Safe local regression gate for tile SQL at overview, state-selection, and system-browsing zooms | Non-destructive; cold timings call `TileGenerator.generate_layer` directly |
| `bin/benchmark-cold` | Manual cold-cache investigation for full tile generation | Destructive; deletes all rows from `tile_cache` before measuring |

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/API.md](docs/API.md) | Endpoint specifications — filter API, tiles, export |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Rails app structure — models, controllers, Stimulus, Turbo patterns |
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
