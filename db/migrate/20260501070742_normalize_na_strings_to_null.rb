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

# ---------------------------------------------------------------------------
# This mirrors the cast_string method in Etl::TypeCaster, which normalizes
# missing-value sentinels at import time. The same logic is applied here so
# that existing records (imported before cast_string was introduced) are
# consistent with all future ETL runs:
#
#   ┌──────────────┬─────────────────────────┬────────────────┬───────────┐
#   │ Value in DB  │ UPPER(TRIM(col)) = 'NA' │ TRIM(col) = '' │  Result   │
#   ├──────────────┼─────────────────────────┼────────────────┼───────────┤
#   │ 'NA'         │ ✓                       │ —              │ → NULL    │
#   │ 'na', ' NA ' │ ✓                       │ —              │ → NULL    │
#   │ ''           │ —                       │ ✓              │ → NULL    │
#   │ '   '        │ —                       │ ✓              │ → NULL    │
#   │ 'Territory'  │ —                       │ —              │ unchanged │
#   └──────────────┴─────────────────────────┴────────────────┴───────────┘
#
# Note: .update_all issues a single SQL UPDATE per column — it does NOT
# load records into Ruby. Model classes are used here for readability; if
# a model is ever renamed, use the raw SQL form below instead.
#
# Raw SQL equivalent:
#
#   COLUMNS = {
#     "public_water_systems" => %w[pws_name primacy_agency ...],
#     "trend_data"           => %w[income_change_flag population_change_flag],
#     "boil_water_summaries" => %w[first_advisory_date last_advisory_date ...]
#   }.freeze
#
#   COLUMNS.each do |table, cols|
#     cols.each do |col|
#       execute "UPDATE #{table} SET #{col} = NULL WHERE UPPER(TRIM(#{col})) = 'NA' OR TRIM(#{col}) = ''"
#     end
#   end
# ---------------------------------------------------------------------------
