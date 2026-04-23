# Drinking Water Explorer

A public-facing data visualization tool that lets anyone explore public water systems across the United States. Filter, map, and download data about water quality, violations, demographics, and funding for ~70,000 community water systems.

Built for [EPIC](https://www.policyinnovation.org/) (Environmental Policy Innovation Center).

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


## Current Deployed Instances (example values)
- **Staging**: https://apps.cnt.org/water-data-tool-staging/
- **Production**: https://apps.cnt.org/water-data-tool/

These URLs reflect the current hosting environment and should be replaced during ownership transfer.

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

6. **Start the app**

   ```bash
   bin/dev
   ```

   Visit [http://localhost:3000](http://localhost:3000)

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `MAPBOX_ACCESS_TOKEN` | Yes | Mapbox GL JS token for map rendering |
| `DB_PORT` | No | PostgreSQL port (default `5432`). Only needed if your Docker container is mapped to a non-default port to avoid a conflict with a local PostgreSQL install — see `docker-compose.override.yml`. |
| `ETL_SOURCE_URL` | **Yes** (setup + ETL) | Base HTTPS URL to the S3 folder containing source data files. Required for both the seed step (`bin/setup`) and the ETL pipeline. |
| `AWS_ACCESS_KEY_ID` | No | For ETL pipeline S3 access (not needed for local dev with seed data) |
| `AWS_SECRET_ACCESS_KEY` | No | For ETL pipeline S3 access |
| `AWS_REGION` | No | Defaults to `us-east-1` |
| `RAILS_ENV` | No | Defaults to `development` |

---

## Ownership Transfer Checklist

Before deploying in a new environment, replace these values with your organization's settings:

- Deploy hosts and container registry in `config/deploy.yml`
- Secret sources in `.kamal/secrets` (`RAILS_MASTER_KEY`, registry credentials)
- `ETL_SOURCE_URL` in `.env` (from `.env.example`)
- Any public app URLs in this README (staging/production)
- DNS, TLS, and infrastructure wiring for your AWS account

---

## Deploying

### Kamal (default, single host)

The app ships with [Kamal](https://kamal-deploy.org/) as its documented portable deployment path. Configuration lives in `config/deploy.yml` and `.kamal/secrets`. This is the recommended approach for self-hosters and community deployments.

Refer to the Kamal docs and the `config/deploy.yml` comments for setup instructions.

### AWS ECS (client-specific, opt-in)

A second deployment path is provided via `.github/workflows/deploy-client-aws.yml`. When enabled, it:

- On `push` to `main` — builds the image, pushes `:main-<sha>` + `:main-latest` to ECR, and force-redeploys the production ECS service.
- On `pull_request` (opened/synchronize/reopened) — pushes `:pr-<n>-<sha>` + `:pr-latest` and redeploys the preview ECS service.

**The workflow is gated by a repo variable.** Leave `AWS_DEPLOY_ENABLED` unset in forks and community deployments — the job will appear as "skipped" rather than failing.

**Repo settings required (set once, after AWS infrastructure is provisioned):**

| Setting | Type | Value |
|---------|------|-------|
| `AWS_DEPLOY_ENABLED` | Variable | `true` |
| `AWS_REGION` | Variable | e.g. `us-east-1` |
| `ECR_REPO_URI` | Variable | e.g. `123456789.dkr.ecr.us-east-1.amazonaws.com/your-ecr-repo` |
| `ECS_CLUSTER` | Variable | ECS cluster name |
| `ECS_SERVICE_PROD` | Variable | Production ECS service name |
| `ECS_SERVICE_PREVIEW` | Variable | Preview ECS service name |
| `AWS_DEPLOY_ROLE_ARN` | Secret | IAM role ARN for OIDC assume-role |

AWS-side provisioning (ECR, ECS cluster/services, IAM OIDC role) is handled separately by the client's infrastructure team.

---

## Development Workflow

```bash
# Start PostgreSQL (if not already running)
docker compose up -d

# Start the Rails app (web server + asset watcher)
bin/dev

# Run tests
bundle exec rspec

# Rails console
bin/rails console

# Seed specific states (downloads from S3 via HTTPS — only needs ETL_SOURCE_URL)
bin/rails 'db:seed:states[VT,RI,OH,CO,PR]'

# Re-seed with fresh data from S3 (seed files are cached in tmp/seeds/ and reused by default)
rm -rf tmp/seeds/ && bin/rails 'db:seed:states[VT,RI,OH,CO,PR]'

# Run full ETL import — loads the entire national dataset (~70k systems)
# Requires ETL_SOURCE_URL + AWS credentials. Safe to run locally for
# performance testing (exports, large filter sets, map rendering at scale).
bin/rails etl:import

# Run ETL import (single table)
bin/rails 'etl:import[epa_sabs]'

# Stop PostgreSQL
docker compose down
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/DISCOVERY.md](docs/DISCOVERY.md) | Discovery notes from the legacy PHP app analysis |
| [docs/SCHEMA.md](docs/SCHEMA.md) | Database schema — all tables, columns, types, indexes |
| [docs/TRANSITION.md](docs/TRANSITION.md) | Migration plan from PHP to Rails with column mapping |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Rails app structure — models, controllers, Stimulus, Turbo patterns |
| [docs/API.md](docs/API.md) | Endpoint specifications — filter API, tiles, export |
| [docs/ETL.md](docs/ETL.md) | Data pipeline design — S3 to PostgreSQL import flow |

---

## License

MIT. See [LICENSE](LICENSE).

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
