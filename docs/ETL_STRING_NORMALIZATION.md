# ETL String Normalization

> **Status:** Implemented. All `cast_string` changes are merged. A data migration (`20260501070742_normalize_na_strings_to_null.rb`) ships with this PR and will clean up existing records in all environments on deploy.

---

## The Problem

Source CSVs from the data publisher use `"NA"` as a missing-value sentinel (common in R/pandas pipelines). Before this fix, the ETL stored `"NA"` literally as a string in the database for text columns, while numeric columns already converted it to `NULL` via `cast_int` / `cast_dec`.

**Effect in the UI:** String columns showed the text `NA` in table cells instead of the standard `—` dash.

**Bonus bug found:** `open_health_viol` was being formatted with `fmt_num` in the table partial, silently coercing `"Yes"`/`"No"` to `0`. Also, rows with `detailed_facility_report: "NA"` rendered a clickable `report` link pointing to the literal URL `NA`.

---

## The Fix

Added `cast_string` to `Etl::TypeCaster`:

```ruby
def cast_string(val)
  return nil if val.nil?
  stripped = val.strip
  return nil if stripped.empty? || stripped.upcase == "NA"
  stripped
end
```

Real categorical values (`"Territory"`, `"State"`, `"Tribal"`, `"Yes"`, `"No"`, `"Surface Water"`, etc.) pass through unchanged. Only the literal sentinel `"NA"` and blank/empty strings become `nil`.

---

## Where `cast_string` Was Applied

### ETL Importers (`app/services/etl/importers/`)

| Importer | Columns changed to `cast_string` | Table |
|---|---|---|
| `epa_sabs.rb` | `pws_name`, `primacy_agency`, `pop_cat_5`, `service_area_type`, `symbology_field`, `detailed_facility_report`, `ewg_report_link` | `public_water_systems` |
| `sdwis_viols.rb` | `gw_sw_code`, `primary_source_code`, `first_reported_date`, `owner_type`, `primacy_type`, `source_water_protection_code`, `phone_number`, `open_health_viol` | `public_water_systems` |
| `xwalk_pct_change_10yr.rb` | `income_change_flag`, `population_change_flag` | `trend_data` |
| `national_bwn_highlevel_summary.rb` | `first_advisory_date`, `last_advisory_date`, `state_reporting_year_min`, `state_reporting_year_max`, `state`, `tooltip_text`, `download_url`, `date_range_display` | `boil_water_summaries` |

### Seed Task (`lib/tasks/seed_states.rake`)

The same columns in both the `build_pws_row` helper and the inline `sdwis_viols`, `xwalk_pct_change_10yr`, and `national_bwn_highlevel_summary` sections.

### Importers with no `cast_string` needed

These were confirmed clean (zero NA/blank values in the national dataset for their string columns, or have no string columns at all):

| Importer | Reason |
|---|---|
| `epa_sabs_xwalk.rb` (`most_common_rate_tidy`) | 0 NA values nationally; 833 rows contain `"No Information on annual water & sewer rates"` — confirmed real category, displayed as-is |
| `cejst.rb`, `ejscreen.rb`, `svi.rb`, `cvi.rb` | All columns are numeric (score/dec/int) |
| `pwsid_funded_highlevel_summary.rb` | All columns are numeric |
| `pwsid_npdes_usts_rmps_imp.rb` | All columns are numeric |
| `epa_sabs_geoms.rb` | Geometry only |

---

## Data Storage & Rendering Rules

### Two categories of "missing" data

The rule: **normalize machine-generated sentinels to NULL; preserve publisher-stated descriptive phrases as-is.** The alternative — converting everything to NULL — would silently discard the publisher's distinction between "no record" and "explicitly stated no information," making the data less auditable and harder to reason about.

| Category | Example values | DB storage | UI renders | Why |
|---|---|---|---|---|
| True missing-value sentinel | `"NA"`, `""`, `"  "` | `NULL` | `—` | Machine-generated placeholder with no semantic meaning; normalizing to NULL is conventional |
| Descriptive absence phrase | `"No Information"`, `"No Information on annual water & sewer rates"`, `"Not Enough Data - Operating < 10 years"` | Stored as-is | String as-is (or `—` if EPIC decides) | Publisher made an explicit statement; the distinction between "no record" and "stated no info" has value |

### Contact fields (e.g. `phone_number`)

Contact fields follow the same rule as descriptive strings: store as-is, render in the UI. `"No Information"` for a phone number is semantically equivalent to nil, but the consistent rule (only nil out `"NA"` and blank) is simpler and avoids column-specific special cases.

### DB query implications

Queries against columns that may contain descriptive absence phrases must account for **both** `NULL` and the phrase string:

```ruby
# Wrong — misses "No Information" rows
PublicWaterSystem.where(source_water_protection_code: nil)

# Correct
PublicWaterSystem.where("source_water_protection_code IS NULL OR source_water_protection_code = 'No Information'")
```

This is expected and conventional — the alternative (converting every descriptive phrase to NULL) would silently discard publisher intent and make the data less auditable.

### Export behavior

`app/exporters/public_water_system_exporter.rb` exports **raw DB values** — no UI formatting is applied. This is the conventional approach for data exports: exports are consumed by analysts, researchers, and downstream systems that need parseable data, not display artifacts.

- `NULL` → empty cell in CSV / `null` in GeoJSON (universal standard for "no data")
- `"No Information"` → exported as `"No Information"`
- `"Not Enough Data - Operating < 10 years"` → exported as that string

The `—` dash is a UI rendering convention only (`fmt_str`, `fmt_bool` in `HomeHelper`) and never appears in exports. Exporting `—` would be wrong — it is a Unicode display character, not meaningful data.

---

## NA Value Counts in National Dataset

Rows that had `"NA"` stored in the DB before this fix (and that a force ETL run will clean up):

| CSV file | Column | Rows with NA |
|---|---|---|
| `xwalk_pct_change_10yr.csv` | `income_change_flag` | 5,399 |
| `xwalk_pct_change_10yr.csv` | `population_change_flag` | 2,607 |
| `epa_sabs.csv` | `service_area_type` | 117 |
| `epa_sabs.csv` | `pws_name`, `pop_cat_5`, `ewg_report_link` | 9 each |
| `national_bwn_highlevel_summary.csv` | `first_advisory_date`, `last_advisory_date` | 19 each |
| `sdwis_viols.csv` | `owner_type` | 5 |
| `epa_sabs.csv` | `primacy_agency` | 1 |

> The 9 `pws_name` / `pop_cat_5` / `ewg_report_link` rows are aggregated multi-PWSID records (e.g. `"ND0501057; ND0501127; ND4001153; ND3501476"`) where the publisher combined systems and had no meaningful values.

---

## View / Helper Fixes (same PR)

| File | Change | Reason |
|---|---|---|
| `_table.html.erb` line 157 | `pws.pws_name` → `fmt_str(pws.pws_name)` | Nil now renders `—` instead of blank |
| `_table.html.erb` line 180 | `fmt_num` → `fmt_str`, `td_num` → `td` | `open_health_viol` is `"Yes"`/`"No"` text, not a number; was silently coercing to `0` |
| `_table.html.erb` line 160 | No code change | `"NA".present?` was true → broken link rendered. Now nil → `present?` false → no link. Fixed for free. |

---

## UI Testing Checklist

**1. No raw "NA" anywhere in the table**
- Open the data table
- `⌘F` → search `NA`
- Zero hits expected in any data cell

**2. "Open violations" column shows text**
- Scroll right to the **Open violations** column
- Should display `Yes`, `No`, or `—`
- If `0` appears, the fix didn't apply to that record (needs ETL re-run)

**3. EPA Facility Report links are valid**
- Click any `report` link in the table — it should open an EPA page
- Rows with no link are correct (those records had no URL in the source data)

**4. Trend flag columns show `—` for unknown**
- Filter to a state with many systems (e.g. CO)
- `income_change_flag` and `population_change_flag` columns should show `—` for the ~5-10% of systems with no trend data

---

## Cleaning Up Existing DB Data

The ETL uses upserts, so a force re-run rewrites all records with correctly-cast values. For local development a force re-run is the simplest approach; deployed environments should use the migration (see below).

```bash
# Fix public_water_systems string columns
bin/rails etl:import[epa_sabs,force]
bin/rails etl:import[sdwis_viols,force]

# Fix trend_data flag columns (~5,399 / 2,607 rows with NA)
bin/rails etl:import[xwalk_pct_change_10yr,force]

# Fix boil_water_summaries date columns (19 rows with NA)
bin/rails etl:import[national_bwn_highlevel_summary,force]
```

If re-seeding from scratch (development):

```bash
bin/rails db:seed:states[VT,RI,OH,CO,PR]
```

The seed task (`seed_states.rake`) was updated in the same PR, so a fresh seed will produce clean data automatically.

---

## Cleaning Up Deployed Environments (Staging / Production)

Existing records in staging and production were imported before this fix and will still have `"NA"` strings in the affected columns. Two options:

---

### Option A — Data Migration (recommended, already written)

`db/migrate/20260501070742_normalize_na_strings_to_null.rb` ships with this PR and runs automatically as part of `db:migrate` during deploy. It requires no S3 access and is idempotent.

```ruby
class NormalizeNaStringsToNull < ActiveRecord::Migration[8.1]
  MODELS = {
    PublicWaterSystem => %w[
      pws_name primacy_agency pop_cat_5 service_area_type symbology_field
      detailed_facility_report ewg_report_link gw_sw_code primary_source_code
      first_reported_date owner_type primacy_type source_water_protection_code
      phone_number open_health_viol
    ],
    TrendDatum => %w[income_change_flag population_change_flag],
    BoilWaterSummary => %w[
      first_advisory_date last_advisory_date state_reporting_year_min
      state_reporting_year_max state tooltip_text download_url date_range_display
    ]
  }.freeze

  def up
    MODELS.each do |klass, cols|
      cols.each do |col|
        klass.where("UPPER(TRIM(#{col})) = 'NA' OR TRIM(#{col}) = ''")
             .update_all(col => nil)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
```

The WHERE condition mirrors `cast_string` exactly — it catches `"NA"` in any case, whitespace-padded variants, and empty/blank strings. `.update_all` issues a single `UPDATE` per column without loading records into Ruby. After this migration runs, all future ETL imports will also produce clean data because `cast_string` is now in the pipeline.

**Safe on empty databases:** if the tables contain no data (e.g. a fresh environment before the first ETL run), the WHERE condition matches zero rows and the migration is a no-op. It is fully idempotent.

---

### Option B — Force ETL Re-run on Each Environment

Bypass the `Last-Modified` timestamp check so all four files re-import regardless of whether they've changed on S3:

```bash
bin/rails etl:import[epa_sabs,force]
bin/rails etl:import[sdwis_viols,force]
bin/rails etl:import[xwalk_pct_change_10yr,force]
bin/rails etl:import[national_bwn_highlevel_summary,force]
```

This must be run manually on each environment after the deploy. It downloads and re-processes the full source files, so it's slower and requires S3 access at the time of execution.

---

### Recommendation

**Use Option A (data migration)** unless a scheduled ETL re-run is already planned for another reason. The migration is zero-touch, ships with the deploy, and is safer in environments where ETL is scheduled infrequently or where direct console access is cumbersome. Option B is fine for development or if you want to pull the latest source data at the same time as cleaning up.

---

## Open Questions

### Pending EPIC confirmation

`xwalk_pct_change_10yr.csv` — `income_change_flag` and `population_change_flag` each contain two distinct kinds of non-data:

| Value | Count | Current handling |
|---|---|---|
| `"NA"` | 5,399 / 2,607 | → `NULL` via `cast_string` → renders `—` |
| `"Not Enough Data - Operating < 10 years"` | 752 each | → stored as-is → currently renders the full phrase |

These two coexist in the same column, which is the ambiguous case. The phrase carries real meaning (the system is too young to have trend data) but may be too verbose for a table cell.

**Confirm with EPIC data team:** should `"Not Enough Data - Operating < 10 years"` display as-is, be shortened, or be suppressed to `—`?

If suppressed: add the phrase to `cast_string`'s normalization list. If shortened: add a `cast_trend_flag` helper. No code change has been made yet.

---

### Sentinel Data Audit (full results)

Columns confirmed as unambiguous real categories (no `NULL`/`NA` coexistence) — safe to store and display as-is:

| CSV | Column | Descriptive phrase | Count |
|---|---|---|---|
| `sdwis_viols.csv` | `gw_sw_code` | `"No Information"` | 13 |
| `sdwis_viols.csv` | `primary_source_code` | `"No Information"` | 13 |
| `sdwis_viols.csv` | `source_water_protection_code` | `"No Information"` | 15,171 |
| `sdwis_viols.csv` | `phone_number` | `"No Information"` | 5,321 |
| `epa_sabs_xwalk.csv` | `most_common_rate_tidy` | `"No Information on annual water & sewer rates"` | 833 |
