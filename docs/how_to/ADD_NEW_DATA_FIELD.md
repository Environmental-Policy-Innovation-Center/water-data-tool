# How To: Add a New Data Field

##### Ingest and/or surface a new data field — filter, table column, or histogram.

The system is **manifest-driven**. **"The manifest" means `config/fields.yml`** (the two are used interchangeably throughout this doc).
- You mostly edit **YAML**. The permit args, sort maps, histogram config, CSV/GeoJSON export, and rendered filter menus all **derive** from it.
- You write **Ruby only** for a migration or a custom importer — and often neither.

See also:
- [docs/FILTERING.md](../FILTERING.md) — how filtering works end-to-end (config sources, AND/OR combining, the DOM contract).
- [docs/ETL.md](../ETL.md) — the import pipeline: generic vs. custom importers, casting, and why data must be declared to be ingested.
- Sibling how-tos: [EDIT_EXISTING_DATA_FIELD.md](EDIT_EXISTING_DATA_FIELD.md) · [REMOVE_EXISTING_DATA_FIELD.md](REMOVE_EXISTING_DATA_FIELD.md).

---

## Start here — pick your path

Everything downstream depends on **where your data comes from**. Find your row; it tells you exactly which steps you do and which you skip.

| Your situation | Path | Steps you do |
|---|---|---|
| **A. New source file** — a file the app doesn't import yet (even if it's in a bucket we already read). | New-file, generic | 1, **2**, 3, 4, (5), (6), 7 |
| **B. New column from a file we already import generically** — the file's already wired up; you want one more column from it. | Existing-file, generic | 1, 3, 4, (5), (6), 7 |
| **C. Column already in the database** — loaded by some importer but not yet shown/filtered. | Surface-only | 3, 4, (5), (6), 7 — **no migration, no import** |
| **D. Value that must be computed, rolled up, split across tables, or parsed from geometry.** | Custom importer | Ruby importer required — see [docs/ETL.md](../ETL.md), then 1, 3, 4, (5), (6), 7 |

Parenthesised steps are conditional (explained inline). Note **Step 2** — it applies only to Path A, and skipping it makes your import silently load nothing.

> **How do I know if my file is "generic"?**
> Generic = a flat 1:1 map: each column you want is exactly one column in the source CSV, copied and type-cast, nothing computed. If that's your file, you write **zero Ruby** for the load. If any value is derived, aggregated, or comes from a non-CSV shape, you're Path D — stop and read [docs/ETL.md](../ETL.md) first.

---

## The flow at a glance

It's the **same linear flow every time** — you only skip the steps your path doesn't need; the order never changes.

1. **Migration** — add a DB column for the value. *(skip on Path C — it already exists)*
2. **Register the source file** in `importer.rb`. *(Path A only)*
3. **`config/fields.yml`** — define the field (`source` / `filter` / `display` / `histogram`). *(always)*
4. **`config/filter_layout.yml`** — place the filter; placement sets AND/OR. *(if filterable)*
5. **`config/tooltips.yml`** — add tooltip copy. *(if you referenced a tooltip)*
6. **`config/table_layout.yml`** — place the column. *(if it's a table column)*
7. **Verify** — import, confirm it populated, add tests, `bin/ci`, eyeball it.

If you already know the app, that list is the whole job. The rest of this doc explains each step.

---

## Worked example used throughout

This is a **real** field in the app — a range filter loaded generically from the `epa_sabs_xwalk` file. Every step below shows what this field looks like at that step.

```yaml
poverty_rate:
  model: demographic
  source: {file: epa_sabs_xwalk, header: "hh_below_pov_per", cast: decimal}
  display: {label: "Households below poverty line", sort: poverty_rate, format: pct, csv_label: "Households below the poverty line (%)"}
  filter: {kind: range, coercion: decimal, label: "Poverty rate", tooltip: poverty_rate, slider_label: "Percentage of households"}
  histogram: {format: percent}
```

- If you only want a **filter**, you need `source:` + `filter:` — the `display:` and `histogram:` blocks are optional and independent. A field needs **at least one** of `source` / `display` / `filter` / `histogram`; omit the rest. Omission is the signal — don't pad with `nil`.

---

## The config files

| File | Owns | You touch it in step… |
|---|---|---|
| `config/fields.yml` | **What a field IS** — model, how it loads (`source`), how it shows / filters / charts. The source of truth. | 3 (always) |
| `config/filter_layout.yml` | **Where a filter sits** — which menu/category, and its order. Placement sets AND/OR logic. | 4 (if filterable) |
| `config/table_layout.yml` | **Where a column sits** — table order + column-picker category. | 6 (if a table column) |
| `config/tooltips.yml` | **Tooltip copy**, keyed by concept; the other files reference the key. | 5 (if it needs a tooltip) |

And, **for Path A only**, one Ruby file:

| File | Owns |
|---|---|
| `app/services/etl/importer.rb` | The list of source files the app knows how to fetch and which importer handles each. |

> Before writing anything, skim the header comment at the top of `config/fields.yml` — it documents every key an entry can have.

---

## Step 1 — Migration: give the value a column to live in

**Paths A, B, D.** (**Path C skips this** — the column already exists.)

New data needs a database column. This app **stores** computed and imported values in columns (it does not derive them at read time), so anything genuinely new needs a migration.

- **New column on an existing table** → `add_column`. Most common.
- **Brand-new table** → create the table, add an ActiveRecord model, and add a `has_one` / `has_many` on `PublicWaterSystem`. **The association name must equal the `model:` you'll use in the manifest** — that's how the automatic LEFT JOIN finds it.

**Run the migration before editing `fields.yml`** — the manifest points at real tables/columns, so they must exist first.

What you choose here flows straight into the manifest:
- The table the column lives on → `model:` (and `db_column:` only if the column name differs from your field key).
- The column's type → the `cast:` and `format:` you'll pick.

Reference: [Active Record Migrations](https://guides.rubyonrails.org/active_record_migrations.html). Check `db/schema.rb` (or the `# == Schema Information` block atop each `app/models/*.rb`) to see what already exists before adding anything.

> `poverty_rate` example: it lives on the `demographic` table as a `decimal` column. A migration added that column before the manifest referenced it.

### Brand-new table: the model, association, registry, factory, and spec

Creating the table is only the first step — several more pieces go with it, all before you touch the manifest. Every existing satellite table (`demographics`, `watershed_hazards`, `boil_water_summaries`, …) follows the same shape; here's `certification_summaries` (added alongside the `rra_certification` field) as a concrete, real example.

**1. The model** — `app/models/certification_summary.rb`:
```ruby
class CertificationSummary < ApplicationRecord
  belongs_to :public_water_system, foreign_key: "pwsid", primary_key: "pwsid", inverse_of: :certification_summary

  validates :pwsid, presence: true
end
```
Just a `belongs_to` back to `PublicWaterSystem` and a presence validation on `pwsid` — that's the whole model for every satellite table in this app (add `include Histogrammable` only if one of the columns feeds a histogram). Don't hand-write the `# == Schema Information` comment block at the top — the `annotaterb` gem regenerates it automatically the next time a `db:*` task runs in development (see `lib/tasks/annotate_rb.rake`).

If the column holds a small fixed set of upstream values, a Rails `enum` is tempting — but only add one if something actually consumes its key-based interface, like `Demographic#most_common_rate_tier` (its key feeds `apply_rate_tier_filter`'s value translation and a dedicated `fmt_rate_tier` label lookup). An enum with nothing wired to it silently breaks table display: its reader returns the enum's *key* (`"certified"`), not the stored value (`"Certified"`) — this app added and then removed exactly that enum on `CertificationSummary` for this reason. Default to a plain string column; reach for `enum` only when you have a concrete second consumer for the key.

**2. The association** — add one line to `app/models/public_water_system.rb`, alongside its siblings:
```ruby
has_one :certification_summary, foreign_key: "pwsid", inverse_of: :public_water_system, dependent: :destroy
```
This is the line Step 1's rule refers to — its name (`:certification_summary`) is exactly the `model:` value you'll write in `fields.yml` (Step 3).

**3. The manifest's model registry** — add one line to `MODEL_CLASSES` in `app/fields/field_registry.rb`, alongside its siblings:
```ruby
certification_summary: "CertificationSummary"
```
This is a separate, hardcoded map from the manifest `model:` symbol to the actual Ruby class — `FieldRegistry.model_class` looks up here, not by guessing a class name from the symbol. Skip it and `fields.yml` will raise `KeyError: key not found` the moment Step 3 writes a field with `model: certification_summary` — do this now so that error never happens.

**4. The export join list** — add one line to `ASSOCIATION_JOINS` in `app/exporters/public_water_system_exporter.rb`, alongside its siblings:
```ruby
LEFT JOIN certification_summaries ON certification_summaries.pwsid = public_water_systems.pwsid
```
This is a third, separate hardcoded list every satellite table needs an entry in, powering CSV/GeoJSON export — it's unconditional, the same one-entry-per-`MODEL_CLASSES`-table shape as Step 1's model registry, not tied to whether any of the table's fields are displayed yet. Skip it and exporting any column later placed in `table_layout.yml` (Step 6) raises `PG::UndefinedTable: missing FROM-clause entry for table "..."` — do this now, alongside the model registry, so that error never happens.

**5. The factory** — `spec/factories/certification_summaries.rb`, needed by any spec that builds one of these rows:
```ruby
FactoryBot.define do
  factory :certification_summary do
    association :public_water_system
    pwsid { public_water_system.pwsid }
    rra_certification { ["Certified", "Uncertified"].sample }
  end
end
```
Most satellite factories default to one fixed value; this one varies since the field only has two states. Pin an explicit value in specs that need one: `build(:certification_summary, rra_certification: "Certified")`.

**6. The model spec** — `spec/models/certification_summary_spec.rb`. Every satellite model spec in this app asserts the same two things and nothing more — the association and the presence validation:
```ruby
require "rails_helper"

RSpec.describe CertificationSummary, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:public_water_system).with_foreign_key("pwsid") }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:pwsid) }
  end
end
```
Copy `spec/models/boil_water_summary_spec.rb` or `spec/models/watershed_hazard_spec.rb` verbatim and swap the class name — there's no field-specific behavior to test here; that belongs in the generic-importer spec (Step 7) instead.

**Run it before touching the model.** `bundle exec rspec spec/models/certification_summary_spec.rb` should fail red with no `belongs_to` / `validates` yet — then fill in the model and rerun until green. Same Red → Green discipline `CLAUDE.md` mandates for every model, concern, and job in this app.

**Once it's green, re-annotate.** Run `bin/rails db:migrate` again — harmless with nothing pending, but it still fires the `annotaterb` hook (`lib/tasks/annotate_rb.rake`) — or run `bundle exec annotaterb models` directly. `.annotaterb.yml` has `exclude_factories: false` and `exclude_tests: false`, so this stamps the `# == Schema Information` block onto the factory and spec files too, not just the model.

---

## Step 2 — Register the new source file  (Path A only)

A source file is only fetched and imported if it's listed in `app/services/etl/importer.rb`. Add your file to **both** maps:

```ruby
# app/services/etl/importer.rb

FILE_IMPORTERS = {
  # ...existing entries...
  "my_new_file" => Etl::Importers::Generic,   # generic = flat CSV, no Ruby
}.freeze

FILE_EXTENSIONS = {
  # ...existing entries...
  "my_new_file" => ".csv",
}.freeze
```

### One filename, three places

Start from the file's name in the S3 bucket — say `my_new_file.csv` — and strip the extension: `my_new_file`. Use that exact string, unchanged, in three places:

1. The `FILE_IMPORTERS` / `FILE_EXTENSIONS` keys above.
2. The `source: {file: my_new_file, ...}` value you'll write in `fields.yml` (Step 3) — this is what actually turns the registration into a working import.
3. The S3 object name itself — the importer fetches `"<ETL_SOURCE_URL>/my_new_file.csv"` literally, so the bucket filename has to match too.

> **Getting the file into the bucket:** the importer reads over HTTP from `ENV["ETL_SOURCE_URL"]` (the staged-data S3 bucket; see `.env` / `.env.example`). A *new* file has to be uploaded there first, named `my_new_file.csv`.

Get any of the three wrong and there's **no error** — just a 404 on fetch or zero rows loaded. If an import "does nothing," this is the first thing to check.

**Expect a failure here, and that's fine.** Right after this step — file registered, but `fields.yml` not touched yet — run `bundle exec rspec spec/services/etl/importer_coverage_spec.rb`. It fails, something like:
```
awia_certification: expected exactly one of generic(etl_mapping)=false, custom_imports=false
```
That's the backstop working as intended: a file can't be registered here and silently left unwired from the manifest. It goes green the moment Step 3 adds the `source:` block — nothing to fix yet, just confirmation you're mid-flow.

Skip this entire step for Paths B, C, D — the file is already registered (B, C) or handled by a custom importer already in the map (D).

---

## Step 3 — `config/fields.yml`: define the field (always)

Add the entry in canonical key order — `model` → `db_column` → `source` → `display` → `filter` → `histogram` — omitting blocks the field doesn't have.

```yaml
poverty_rate:
  model: demographic              # base table = public_water_system; any other value auto-LEFT-JOINs
  # db_column: poverty_rate       # ONLY if the real column name differs from the key above — usually omit
  source:                         # Paths A & B. Omit for Path C (already loaded) and Path D (uses custom_imports).
    file: epa_sabs_xwalk          #   must equal the FILE_IMPORTERS key (Step 2) AND the bucket object name
    header: "hh_below_pov_per"    #   the column's EXACT name in the CSV — always quoted, copied verbatim
    cast: decimal                 #   integer | decimal | string | score (0–1 → %) | bool
  display:                        # omit if not shown as a table column
    label: "Households below poverty line"   #   <th> header text — often differs from filter.label
    sort: poverty_rate            #   sort param (omit → not sortable); may differ from key
    format: pct                   #   str | num | dec | pct | cur | bool | check | link | copy
    csv_label: "Households below the poverty line (%)"   #   verbose CSV header
  filter:                         # omit if not filterable
    kind: range                   #   range | radio | bool | multiselect
    coercion: decimal             #   range only: decimal | integer — how the slider values are cast
    label: "Poverty rate"         #   the MENU label shown in the filter — often differs from display.label
    tooltip: poverty_rate         #   a key into config/tooltips.yml (Step 5); omit if none
    slider_label: "Percentage of households"   # range only: caption under the slider; omit if none
  histogram:                      # omit if not histogram-capable
    format: percent               #   percent | currency | count | percent_change
```

If you set `db_column`, know its blast radius: it only affects import (`FieldRegistry`'s ETL mapping) and export (`PublicWaterSystemExporter`'s CSV/GeoJSON column). Table display always reads the AR attribute named after the field *key*, never `db_column` — so a stale or wrong `db_column` silently exports a different column's value than what's shown on screen, with no error. See the `db_column` bullet under "Tests" below for the spec pattern that catches this.

Notes for a filter:
- **`kind`** picks the control: `range` (numeric slider), `radio` (one-of), `bool` (yes/no), `multiselect` (many-of). A numeric column → almost always `range`.
- **`range` needs `coercion`** so the min/max are cast correctly — don't omit it on numeric filters.
- **`bool` on a non-boolean column needs `checked_value`.** The predicate defaults to comparing against a real boolean `true`; if the column is a two-value string instead (an enum-like column, e.g. `rra_certification`'s `Certified`/`Uncertified`), set `checked_value:` to whatever "checked" should compare against. See the `fields.yml` header for the shape and `rra_certification` for a real example.
- **`radio` / `multiselect` need an `options:` list** instead of a `label`; `range` / `bool` never use `options`. See the `fields.yml` header for the `options:` shape.
- **The URL param is permitted automatically.** `FieldRegistry.permit_arguments` (in `app/fields/field_registry.rb`) derives it from `filter.kind` — there is no permit code to edit.

**Base vs. join tables:**
- `public_water_systems` is the base table → `model: public_water_system`.
- Any other `model:` value (`demographic`, `violations_summary`, `funding_summary`, …) is **automatically LEFT JOINed** when the field is filtered or sorted — no join code to write.
- The only requirement is that the association from Step 1 exists.

---

## Step 4 — `config/filter_layout.yml`: place the filter (if filterable)

Add your field key to a category's `filters:` list. **Placement determines more than where the filter appears — it also decides whether it ORs or ANDs with the filters around it:**

- Filters in the **same category** are **OR**'d together.
- Filters in **different categories** are **AND**'d together.

So dropping your filter into an existing category ORs it with that category's siblings; starting a new category ANDs it against everything else. Choose deliberately — see [docs/FILTERING.md](../FILTERING.md).

```yaml
# config/filter_layout.yml — e.g. adding poverty_rate under Population › Socioeconomics
socioeconomics:
  label: "Socioeconomics"
  filters:
    - poverty_rate
    - unemployment_rate
    # ...
```

> **No entry here = URL-only.** The filter still works via its param but appears in no menu. That's a valid choice, not an error — just leave it out of the layout.

---

## Step 5 — Tooltip (optional)

If your `filter:` / `display:` block referenced a `tooltip:` key, add the copy in `config/tooltips.yml` under the matching key. If you didn't reference one, skip this step.

```yaml
# config/tooltips.yml
filter_menus:
  poverty_rate: "Share of households in the service area with income below the federal poverty line."
```

---

## Step 6 — `config/table_layout.yml`: show it as a column (only if displayed)

Only if you added a `display:` block and want the field in the data table. Add the field key to a category's `columns:` list — this sets column order and the column-picker group. These columns also feed both exports (CSV: user-selected subset; GeoJSON: all, as feature properties).

```yaml
# config/table_layout.yml
socioeconomics:
  label: "Socioeconomics"
  columns:
    - poverty_rate
    # ...
```

> No entry here = the column is simply hidden. A **filter-only** field (no `display:` block) does not appear here at all — that's expected.

---

## Step 7 — Verify

### 1. Run the importer for just your file (Paths A, B, D)

The `only:` argument limits the run to one file; `force: true` skips the "unchanged since last import" timestamp check (needed to re-run the same file).

Rails console:
```ruby
Etl::Importer.new(only: "my_new_file", force: true).call
```

Or the rake task (quote the brackets in zsh):
```sh
bin/rails 'etl:import[my_new_file]'         # single file
bin/rails 'etl:import[my_new_file,force]'   # force re-import regardless of timestamp
```

**If it loads zero rows,** re-check the three-name rule (Step 2) and confirm the file is actually at `<ETL_SOURCE_URL>/my_new_file.csv`.

### 2. Confirm the column populated

Query the model — use the field's `model:` (here `demographic` → `Demographic`):
```ruby
Demographic.where.not(poverty_rate: nil).count   # how many rows got a value
Demographic.first.poverty_rate                    # spot-check one
```

### 3. Tests — match what you turned on

Copy an existing field's assertions as your template — find one with the same `kind` / capability and adapt the key, label, and values.

- **New model (brand-new table)** → `spec/models/<model>_spec.rb` — see Step 1's model/spec walkthrough for the base `associations` + `validations` pattern every satellite model follows.
- **Filter behavior** → `spec/models/concerns/filterable_spec.rb`. This exercises `PublicWaterSystem.apply_filters(...)`; add a case like the existing ones (e.g. `apply_filters(symbology_field: "Modeled")`) asserting your filter includes/excludes the right rows.
- **Filter renders in its menu** → `spec/requests/home_spec.rb` — the server-render specs that walk `filter_layout.yml` and assert each menu/tab renders.
- **Column** → `spec/columns/table_layout_spec.rb`.
- **The import actually maps your file correctly (Path A)** → `spec/services/etl/importers/generic_spec.rb`. Drop a small fixture at `spec/fixtures/etl/my_new_file.csv` (a header row + a couple of data rows), then add a `#parse` assertion proving `header → column → cast` — e.g. `expect(parse_fixture("my_new_file").first).to include(my_field: <expected cast value>)`. This is the spec that confirms your data will import correctly, with **no S3 and no live DB needed**.
- **Import wiring backstop** → `spec/services/etl/importer_coverage_spec.rb` enforces that every registered file is either generic-with-`source:` or listed in `custom_imports:` (never both). A new Path-A file must satisfy it — it's the check that catches a file registered in Step 2 but not wired in Step 3.
- **Brand-new table, exported** → no new test needed, but `bin/ci`'s `spec/exporters/public_water_system_exporter_spec.rb` and `spec/requests/exports_spec.rb` will fail loudly (`PG::UndefinedTable: missing FROM-clause entry`) if Step 1's export join list entry was skipped — that's the existing coverage catching it, not a gap to fill.
- **Set `db_column` on this field?** Add a value-assertion export spec: create a record with a distinct value for both the field's own column and whatever other column shares the table, export it, and assert the CSV cell equals the field's value (see `public_water_system_exporter_spec.rb`'s `"exports a field's own column value, not a different same-model column"` for the pattern). Nothing else in `bin/ci` checks this — a wrong `db_column` exports silently, with no error.

### 4. (Optional) Local dev data — how seeding works

You don't need this to ship, but it's how you get sample rows locally.

- **Prod** is populated by the full ETL run (`bin/rails etl:import`), which reads every registered file from S3.
- **Local dev** uses `bin/rails db:seed` → `db:seed:states[...]` (`lib/tasks/seed_states.rake`). It downloads the same S3 files into `tmp/seeds/` but maps them with **hardcoded, per-file logic** for a few states.
- **Consequence for a brand-new file:** the seed task will *download* it (it iterates `FILE_IMPORTERS`), but it won't map your new column into the dev DB unless someone adds a step to `SeedImport`. So after a `db:seed`, your new field may be blank locally even though the wiring is correct.
- **To see your data locally now:** just run the targeted importer against your dev DB — `Etl::Importer.new(only: "my_new_file", force: true).call` (the same command as step 1 above). That populates the real column without touching the seed path.
- The committed CSVs under `db/seeds/csv/` are **not** part of this flow (nothing references them); don't rely on adding a file there.

### 5. Run the full check and eyeball it

```sh
bin/ci
```
- If it fails, see [FIX_BIN_CI_CHECK_FAILURES.md](FIX_BIN_CI_CHECK_FAILURES.md).
- Then load the app locally and confirm the field shows up where you intended — the right filter menu, the right column-picker group, a working slider.

---

## Quick recap — new filter from a new CSV (Path A)

1. **Migration** — add the column (Step 1).
2. **Register the file** in `importer.rb`, both maps; obey the three-name rule (Step 2).
3. **`fields.yml`** — `source:` + `filter:` blocks (Step 3).
4. **`filter_layout.yml`** — place it; remember category = OR, cross-category = AND (Step 4).
5. **`tooltips.yml`** — if you referenced a tooltip (Step 5).
6. *(Skip Step 6 unless you also want a table column.)*
7. **Import, verify the column populates, add tests, `bin/ci`, eyeball it** (Step 7).

---

## Appendix — a full Path A example, start to finish

A concrete run-through for a **new filter from a new CSV**. Say we get a new file `water_hardness.csv` in the bucket, with a column `hardness_mg_l`, and we want a numeric range filter "Water hardness" on the `demographic` model. (Fictional field, illustrating every touchpoint.)

**0. The source file** — `water_hardness.csv`, staged at `<ETL_SOURCE_URL>/water_hardness.csv`:
```csv
pwsid,hardness_mg_l
0100001,120.5
0100002,None
```

**1. Migration** — add the column:
```ruby
# db/migrate/XXXXXX_add_water_hardness_to_demographics.rb
class AddWaterHardnessToDemographics < ActiveRecord::Migration[8.1]
  def change
    add_column :demographics, :water_hardness, :decimal
  end
end
```
```sh
bin/rails db:migrate
```

**2. Register the file** — `app/services/etl/importer.rb`, both maps (three-name rule: `water_hardness` everywhere):
```ruby
FILE_IMPORTERS  = { # ...
  "water_hardness" => Etl::Importers::Generic }.freeze
FILE_EXTENSIONS = { # ...
  "water_hardness" => ".csv" }.freeze
```

**3. `config/fields.yml`** — define the field (filter-only, so no `display:`):
```yaml
water_hardness:
  model: demographic
  source: {file: water_hardness, header: "hardness_mg_l", cast: decimal}
  filter: {kind: range, coercion: decimal, label: "Water hardness", tooltip: water_hardness, slider_label: "mg/L"}
```

**4. `config/filter_layout.yml`** — place it. Its own category ANDs it against everything else; adding it beside siblings ORs it with them. Here we give it a new category under an existing menu:
```yaml
water_quality: {label: "Water quality", filters: [water_hardness]}
```

**5. `config/tooltips.yml`** — the copy for the `water_hardness` key we referenced:
```yaml
filter_menus:
  water_hardness: "Dissolved calcium and magnesium in the water, in milligrams per liter."
```

**6.** Skipped — filter-only, not a table column.

**7. Verify:**
```ruby
# import just this file against dev
Etl::Importer.new(only: "water_hardness", force: true).call
# confirm it populated (None → nil is expected)
Demographic.where.not(water_hardness: nil).count
```
Add a fixture `spec/fixtures/etl/water_hardness.csv` and a `generic_spec` assertion:
```ruby
it "water_hardness: decimal, None → nil" do
  rows = parse_fixture("water_hardness")
  expect(rows.first[:water_hardness]).to eq(BigDecimal("120.5"))
  expect(rows.last[:water_hardness]).to be_nil
end
```
Then a filter-behavior case in `spec/models/concerns/filterable_spec.rb`, and finally:
```sh
bin/ci
```
Load the app and confirm "Water hardness" appears as a slider in the Water quality category and filters the table.
