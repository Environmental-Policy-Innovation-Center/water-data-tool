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

   Edit `.env` and add your Mapbox access token. Most developers only need `MAPBOX_ACCESS_TOKEN` — see the Environment Variables section below if you have a port conflict with a local PostgreSQL install.

4. **Start PostgreSQL**

   ```bash
   docker compose up -d
   ```

   This starts a PostGIS-enabled PostgreSQL container. The database runs on `localhost:5432`.

5. **Set up the databases**

   ```bash
   bin/rails db:setup
   ```

   Creates both the development and test databases, loads the schema, and seeds sample data into development. See `db/seeds.rb` for details on what gets loaded.

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
| `ETL_MANIFEST_URL` | No (Yes for ETL) | HTTPS endpoint for your organization's ETL manifest (`data.json`). |
| `AWS_ACCESS_KEY_ID` | No | For ETL pipeline S3 access (not needed for local dev with seed data) |
| `AWS_SECRET_ACCESS_KEY` | No | For ETL pipeline S3 access |
| `AWS_REGION` | No | Defaults to `us-east-1` |
| `RAILS_ENV` | No | Defaults to `development` |

---

## Ownership Transfer Checklist

Before deploying in a new environment, replace these values with your organization's settings:

- Deploy hosts and container registry in `config/deploy.yml`
- Secret sources in `.kamal/secrets` (`RAILS_MASTER_KEY`, registry credentials)
- `ETL_MANIFEST_URL` in `.env` (from `.env.example`)
- Any public app URLs in this README (staging/production)
- DNS, TLS, and infrastructure wiring for your AWS account

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

# Run ETL import (full)
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
