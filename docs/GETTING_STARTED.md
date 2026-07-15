# Getting Started — First-Time Setup

A step-by-step walkthrough for setting up this app locally, written for people who have **never set up a Rails project before**. It covers installing every tool from scratch.

If you've run Rails apps before, the [Quick Start in the README](../README.md#quick-start) is all you need — this guide is the long form of the same steps.

> Commands below assume **macOS with [Homebrew](https://brew.sh/)**. Linux equivalents are noted where they differ; on Windows we recommend [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) and following the Linux steps.

---

## What you'll install

| Tool | Why you need it |
|---|---|
| **Git** | Download the code and track changes. |
| **A Ruby version manager + Ruby 3.4.7** | Run the app. The version manager keeps this project's Ruby separate from your system Ruby. |
| **Docker Desktop** | Runs the PostgreSQL + PostGIS database. (Prefer a native install? See [Appendix A](#appendix-a--running-postgresql-natively-instead-of-docker).) |
| **GDAL** (`ogr2ogr`) | Loads the Census map-boundary files during setup. |

You'll fill in a couple of values in `.env` — the data source URL (from a project admin) and a Mapbox token (from an admin or a free account). Step 6 covers both.

Work through the sections in order. Total time is roughly 30–60 minutes, most of it downloads.

---

## 1. Install Git

Check whether you already have it:

```bash
git --version
```

If that errors:
- **macOS:** `xcode-select --install` (installs Git and command-line tools), or `brew install git`.
- **Linux (Debian/Ubuntu):** `sudo apt-get install git`.

New to Git? [GitHub's "Set up Git" guide](https://docs.github.com/en/get-started/git-basics/set-up-git) covers first-time configuration (`git config --global user.name` / `user.email`).

---

## 2. Install Ruby 3.4.7 (via a version manager)

This project pins its Ruby version in the `.ruby-version` file (currently **3.4.7**). Don't install Ruby directly — use a **version manager** so each project can use its own version. Common options:

- **[rbenv](https://github.com/rbenv/rbenv)** — recommended; simple and widely used.
- [RVM](https://rvm.io/)
- [mise](https://mise.jdx.dev/)
- [asdf](https://asdf-vm.com/)
- [chruby](https://github.com/postmodern/chruby)

### Using rbenv (our example)

```bash
# macOS
brew install rbenv ruby-build

# Linux: see https://github.com/rbenv/rbenv#installation
```

Wire rbenv into your shell (one time), then restart your terminal:

```bash
# zsh (the macOS default)
echo 'eval "$(rbenv init - zsh)"' >> ~/.zshrc

# bash
echo 'eval "$(rbenv init - bash)"' >> ~/.bashrc
```

Install the project's Ruby:

```bash
rbenv install 3.4.7
```

Once you've cloned the repo (step 5) and `cd` into it, rbenv reads `.ruby-version` automatically. Verify inside the project folder:

```bash
ruby -v          # should print 3.4.7
```

Ruby ships with **Bundler** (the gem installer this project uses). If `bundle -v` errors, run `gem install bundler`.

---

## 3. Install Docker Desktop (for the database)

The app needs **PostgreSQL 15 with the PostGIS extension**. The easiest way to get exactly that is Docker, which runs it in a container without touching your system.

1. Download and install [Docker Desktop](https://www.docker.com/products/docker-desktop/).
2. Launch Docker Desktop and wait until it says it's running.
3. Verify from a terminal:

   ```bash
   docker --version
   docker compose version
   ```

You'll start the database container in step 7.

> Prefer not to use Docker? You can install PostgreSQL 15 + PostGIS natively instead — see [Appendix A](#appendix-a--running-postgresql-natively-instead-of-docker).

---

## 4. Install GDAL (`ogr2ogr`)

Setup loads Census cartographic boundary files using GDAL's `ogr2ogr` tool.

```bash
# macOS
brew install gdal

# Linux (Debian/Ubuntu)
sudo apt-get install gdal-bin
```

Verify:

```bash
ogr2ogr --version
```

---

## 5. Clone the repository

```bash
git clone https://github.com/epicenter/water-data-tool.git
cd water-data-tool
```

If you're working from a transferred or forked repo, substitute your own remote URL.

---

## 6. Configure environment variables

Copy the template:

```bash
cp .env.example .env
```

A few values are placeholders you must fill in. None are committed to the repo — request them from a project admin (see [Requesting access to config values](../CONTRIBUTING.md#requesting-access-to-config-values); Mapbox you can also self-serve):

- `ETL_SOURCE_URL` — the source-data location; **get it from a project admin**. The bucket is public and read-only, so once you have the URL no AWS credentials are needed.
- `MAPBOX_ACCESS_TOKEN` — get one from a project admin, or create your own free token at [account.mapbox.com/access-tokens](https://account.mapbox.com/access-tokens/) (the default public `pk.` token is fine). These tokens are visible in the browser at runtime, so whoever owns it should **URL-restrict it** (allowlist your domains) in the Mapbox dashboard.
- `MAPBOX_STYLE_URL` — use your team's style, or a Mapbox default: `mapbox://styles/mapbox/light-v11`.

You do **not** need AWS credentials for local development — those are only for the production ETL pipeline.

`.env` is gitignored — **never commit it**. Only `.env.example` is tracked. See the [Environment Variables table in the README](../README.md#environment-variables) for what each variable does.

---

## 7. Start the database

With Docker Desktop running:

```bash
DOCKER_DEFAULT_PLATFORM=linux/amd64 docker compose up -d
```

This starts a PostGIS-enabled PostgreSQL container on `localhost:5432`, preconfigured with the `postgres` / `postgres` credentials the app expects. It keeps running in the background until you stop it with `docker compose down`.

(Using a native install instead? Follow [Appendix A](#appendix-a--running-postgresql-natively-instead-of-docker), then continue here.)

---

## 8. Install dependencies and set up the app

```bash
bundle install
bin/setup
```

- `bundle install` downloads the Ruby gems (libraries) the app depends on.
- `bin/setup` creates and migrates the database, then seeds development data. The seed step downloads water-system data from S3 and loads Census boundaries with `ogr2ogr`.

**This takes several minutes on the first run** — the national boundary file is large, but it's cached in `tmp/seeds/` so later runs are fast. By default it seeds a few states for broad filter coverage (see the [README](../README.md#quick-start) for which and why).

---

## 9. Install Git hooks (recommended)

The repo uses [Lefthook](https://github.com/evilmartians/lefthook) to run linters on your staged files before each commit. Register the hooks once per clone:

```bash
bundle exec lefthook install
```

---

## 10. Run the app

```bash
bin/dev
```

Then open [http://localhost:3000](http://localhost:3000). You should see the map with data for the seeded states.

To stop: press `Ctrl+C` in the terminal running `bin/dev`, and `docker compose down` when you're finished with the database.

---

## Verify your setup (optional)

Not required, but a good confidence check that everything is wired correctly — run the project's deterministic CI once:

```bash
bin/ci
```

If it passes, your Ruby, database, and dependencies are all healthy. If it fails, see [the linting/CI commands below](#after-setup--everyday-commands) and [`docs/how_to/FIX_BIN_CI_CHECK_FAILURES.md`](how_to/FIX_BIN_CI_CHECK_FAILURES.md).

---

## After setup — everyday commands

These are the commands you'll use day to day. The [Development Workflow section of the README](../README.md#development-workflow) has the complete list; the essentials:

- **Run the test suite:**
  ```bash
  bundle exec rspec                 # all specs
  bundle exec rspec path/to/spec.rb # one file
  ```
  A failing spec prints the file, line, and the expected-vs-actual diff. Fix the code (or the spec, if the behavior legitimately changed) and re-run just that file until green.

- **Run the full project CI** (what must pass before merging):
  ```bash
  bin/ci
  ```
  If it fails, see [`docs/how_to/FIX_BIN_CI_CHECK_FAILURES.md`](how_to/FIX_BIN_CI_CHECK_FAILURES.md) for how to interpret and fix each check.

- **Lint Ruby** ([Standard](https://github.com/standardrb/standard)):
  ```bash
  bin/standardrb            # check
  bin/standardrb --fix      # auto-fix what's safe, then review the diff
  ```

- **Lint ERB templates** ([ERB Lint](https://github.com/Shopify/erb-lint)):
  ```bash
  bin/erb_lint --lint-all
  bin/erb_lint --lint-all --autocorrect
  ```

- **Open a Rails console** (inspect data, try queries):
  ```bash
  bin/rails console
  ```

The Ruby and ERB linters are the same ones the Git hook (step 9) runs on commit, so installing the hook catches most issues before you even run them manually.

---

## Best practices & conventions

A few project conventions that aren't obvious from the code:

- **Never hand-edit `db/schema.rb`.** It's auto-generated from the database. To change the schema, write a migration (`bin/rails generate migration …`) and run `bin/rails db:migrate`; Rails regenerates `schema.rb` for you. Commit the migration *and* the regenerated schema.
- **Filters, table columns, and tooltips are config-driven.** Add / edit / remove them by editing the YAML in `config/` (see [Configuration in the README](../README.md#configuration-filters-table-columns-tooltips) and the [`docs/how_to/`](how_to/) guides) — not by hand-editing derived code.
- **Never commit secrets.** `.env` is gitignored; only `.env.example` is tracked. If you add a new environment variable, add a placeholder for it to `.env.example` so the next person knows it exists.
- **Use Bundler, not manual gem installs.** Add gems to the `Gemfile` and run `bundle install`; commit the resulting `Gemfile.lock` changes so everyone gets the same versions.
- **Run `bin/ci` (and the linters) before opening a PR.** The Git hook covers linting on commit; `bin/ci` is the full pre-merge gate.
- **Branch off `main`.** Open a pull request rather than committing to `main` directly — each PR gets its own preview environment (see the README).

---

## Troubleshooting

**`ruby -v` doesn't show 3.4.7 inside the project**
Make sure you ran `rbenv install 3.4.7`, added the `rbenv init` line to your shell config, and restarted the terminal. Run `rbenv version` to see which version rbenv thinks is active and why.

**`bundle install` fails with a Ruby version mismatch**
You're on the wrong Ruby. Confirm `ruby -v` prints 3.4.7 from inside the project directory (see step 2).

**Port 5432 is already in use**
Another PostgreSQL is running (often a native Homebrew install). Either stop it, or remap the Docker container to another port via a `docker-compose.override.yml` and set `DB_PORT` in `.env` — see the note in `.env.example`.

**`ogr2ogr: command not found` during `bin/setup`**
GDAL isn't installed or isn't on your `PATH` — revisit step 4.

**The database can't be reached**
Confirm Docker Desktop is running and the container is up: `docker compose ps` should list the `db` service. Start it with `docker compose up -d`.

**Map tiles are blank / the map doesn't load**
Check `MAPBOX_ACCESS_TOKEN` and `MAPBOX_STYLE_URL` in `.env`, then restart `bin/dev`.

Still stuck? See [`docs/how_to/FIX_BIN_CI_CHECK_FAILURES.md`](how_to/FIX_BIN_CI_CHECK_FAILURES.md) for CI-related issues, or ask the team.

---

## Appendix A — Running PostgreSQL natively (instead of Docker)

If you'd rather not use Docker, you can install PostgreSQL 15 + PostGIS directly. This replaces step 7 only; everything else in the guide is unchanged.

```bash
# macOS (Homebrew)
brew install postgresql@15 postgis
brew services start postgresql@15
createuser -s postgres          # the app defaults to a `postgres` superuser role
```

Notes:
- **Match the versions.** Ensure the PostGIS build corresponds to PostgreSQL 15.
- **The role must be a superuser** (`-s`) so the app's migrations can run `CREATE EXTENSION postgis`. Alternatively, point the app at your own local role by setting `DB_USERNAME` / `DB_PASSWORD` in `.env`.
- **Port.** The app connects on `localhost:5432` by default. If something else already uses that port, set `DB_PORT` in `.env`.
- **Start / stop** the service with `brew services start postgresql@15` and `brew services stop postgresql@15`.

Docker remains the recommended path because it matches CI and production exactly; the native route is a supported convenience, but version and extension mismatches are yours to manage.
