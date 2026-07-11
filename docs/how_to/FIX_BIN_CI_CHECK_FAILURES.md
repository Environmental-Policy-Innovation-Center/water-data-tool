# How To: Fix `bin/ci` / CI Check Failures

##### What each CI check is, and how to fix it when it fails.

`bin/ci` runs the same checks GitHub Actions runs on your PR. Locally they run **in sequence and stop at the first failure**; on GitHub they run as **parallel jobs** (`.github/workflows/ci.yml`), so you may see several fail at once. Either way, the checks are the same.

| Order | Check | Command | GitHub job |
|---|---|---|---|
| 1 | Setup | `bin/setup --skip-server` | *(each job sets up its own environment)* |
| 2 | Ruby style | `bin/standardrb` | `lint` |
| 3 | ERB style | `bin/erb_lint --lint-all` | *(bin/ci + commit hook only)* |
| 4 | Gem security audit | `bin/bundler-audit` | `scan_ruby` |
| 5 | JS dependency audit | `bin/importmap audit` | `scan_js` |
| 6 | Ruby static analysis | `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` | `scan_ruby` |
| 7 | Tests | `bundle exec rspec` | `test` |

> Run any single check on its own with the command in the table — you don't have to re-run all of `bin/ci` to check one fix.

---

## 1. Setup — `bin/setup --skip-server`

**What it is:** installs gems, updates the local security-advisory database, and prepares the database (`bin/rails db:prepare`).

**Why it fails:** usually a `bundle install` failure (missing system dependency, gem source issue) or a database that `db:prepare` can't reach/migrate.

**How to fix:** read the actual error — it's the same as running `bundle install` or `bin/rails db:prepare` by hand. Fix that underlying issue, then re-run.

---

## 2. Ruby style — `bin/standardrb`

**What it is:** Ruby linting/formatting via [Standard](https://github.com/standardrb/standard) (a RuboCop wrapper). Config lives in `.standard.yml`.

**How to fix:** most violations auto-correct:

```bash
bin/standardrb --fix
```

Review the diff afterward, then re-run `bin/standardrb` to confirm it's clean. Anything left after `--fix` needs a manual edit — the output names the file, line, and rule.

---

## 3. ERB style — `bin/erb_lint --lint-all`

**What it is:** linting for `.html.erb` templates via [ERB Lint](https://github.com/Shopify/erb-lint). Config lives in `.erb_lint.yml`.

> This runs in `bin/ci` and the pre-commit hook, but **not** as a separate GitHub Actions job — so it won't show up as a red check on the PR. Catch it locally.

**How to fix:**

```bash
bin/erb_lint --lint-all --autocorrect
```

Review the diff and re-run to confirm. Remaining issues are named with file and line for a manual fix.

---

## 4. Gem security audit — `bin/bundler-audit`

**What it is:** scans `Gemfile.lock` for gems with known security advisories (CVEs).

**Why it fails:** one of your gems has a published vulnerability, or the local advisory database is stale.

**How to fix:**

1. Refresh the advisory database first (rules out a stale-DB false alarm):
   ```bash
   bin/bundler-audit update
   ```
2. The report names the gem and the advisory. Bump that gem to a patched version:
   ```bash
   bundle update --conservative <gem>   # smallest change that clears the advisory
   ```
3. Commit the updated `Gemfile.lock`.

**Patch vs. larger bumps** — prefer the smallest bump that resolves the advisory:

- **Patch** (`1.2.3 → 1.2.4`) — backwards-compatible bug/security fixes. Safe; usually just update and move on.
- **Minor** (`1.2.x → 1.3.0`) — new features, still backwards-compatible under semver. Low risk; run the tests.
- **Major** (`1.x → 2.0`) — breaking changes. Read the gem's changelog/upgrade notes and run the full suite before committing.

`--conservative` keeps the bump minimal so you don't accidentally drag in a major upgrade. Only reach for a major bump if no patched version exists on your current major line.

---

## 5. JS dependency audit — `bin/importmap audit`

**What it is:** checks the JavaScript packages pinned in `config/importmap.rb` for known vulnerabilities. (This app uses import maps — there is no `package.json` / npm.)

**How to fix:** update the flagged package to a patched version:

```bash
bin/importmap pin <package>            # repin to the latest
bin/importmap pin <package>@<version>  # or a specific patched version
```

Commit the change to `config/importmap.rb` (and any vendored file under `vendor/javascript/` if the package is downloaded rather than served from a CDN).

---

## 6. Ruby static analysis — `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`

**What it is:** scans Rails code for security issues (SQL injection, XSS, mass assignment, etc.).

**Known false positives** are recorded in `config/brakeman.ignore` — each is a **fingerprint** (a SHA of the flagged code) plus a `note` explaining why it's safe.

**Why it fails after an unrelated change:** the fingerprint is computed from the flagged code and its surroundings. Rename a variable, move a line, or edit nearby code, and the fingerprint changes — so the existing ignore entry no longer matches and Brakeman re-surfaces the (still-false-positive) warning.

**How to fix:**

- **If it's the same false positive** (the flagged code is fundamentally unchanged, just renamed/moved) — regenerate the fingerprint with interactive ignore mode:
  ```bash
  bin/brakeman -I
  ```
  Step through the warning, confirm it's the known false positive, and re-add it to the ignore list, **carrying over the existing note**. This rewrites the fingerprint in `config/brakeman.ignore`. Commit that file.
- **If it's a genuinely new warning** — don't ignore it. Fix the code (e.g. parameterize the query, escape the output). Only add to `config/brakeman.ignore` when you're certain it's a false positive, and always write a `note` saying why.

---

## 7. Tests — `bundle exec rspec`

**What it is:** the RSpec test suite.

**How to fix:**

1. The failure output names the spec file, line, and an expected-vs-actual diff. Re-run just that file (or example) while you work:
   ```bash
   bundle exec rspec path/to/failing_spec.rb
   bundle exec rspec path/to/failing_spec.rb:42   # a single example by line
   ```
2. Decide which side is wrong:
   - **The code regressed** → fix the code.
   - **The behavior changed on purpose** → update the spec to match.
3. Re-run the file until green, then run the full suite (or `bin/ci`) once more.

> Some specs are **config-driven golden masters** — they assert the composed output of `config/*.yml`. If you changed a field, filter, or column, an expected-value update in these specs is normal. See [ADD_NEW_DATA_FIELD.md](ADD_NEW_DATA_FIELD.md) for which specs each capability touches.

---

## After a fix

Re-run the single check to confirm, then run the whole gate before pushing:

```bash
bin/ci
```

Green locally = green on GitHub (the checks are identical), minus the parallel-vs-sequential difference noted at the top.
