# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_30_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "postgis"

  create_table "boil_water_summaries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "date_range_display"
    t.string "download_url"
    t.string "first_advisory_date"
    t.string "last_advisory_date"
    t.string "pwsid", null: false
    t.string "state"
    t.string "state_reporting_year_max"
    t.string "state_reporting_year_min"
    t.text "tooltip_text"
    t.integer "total_notices"
    t.datetime "updated_at", null: false
    t.index ["pwsid"], name: "index_boil_water_summaries_on_pwsid", unique: true
  end

  create_table "cartographic_counties", primary_key: "gid", id: :integer, default: nil, force: :cascade do |t|
    t.string "countyfp", limit: 3
    t.string "geoid", limit: 5
    t.geometry "geom", limit: {srid: 4326, type: "multi_polygon"}
    t.string "name"
    t.string "namelsad"
    t.string "statefp", limit: 2
    t.string "stusps", limit: 2
    t.index ["geom"], name: "index_cartographic_counties_on_geom", using: :gist
    t.index ["namelsad", "stusps"], name: "index_cartographic_counties_on_namelsad_and_stusps"
  end

  create_table "cartographic_places", primary_key: "gid", id: :integer, default: nil, force: :cascade do |t|
    t.string "affgeoid"
    t.string "geoid", limit: 7
    t.geometry "geom", limit: {srid: 4326, type: "multi_polygon"}
    t.string "name"
    t.string "namelsad"
    t.string "placefp", limit: 5
    t.string "statefp", limit: 2
    t.string "stusps", limit: 2
    t.index ["affgeoid"], name: "index_cartographic_places_on_affgeoid"
    t.index ["geoid"], name: "index_cartographic_places_on_geoid"
    t.index ["geom"], name: "index_cartographic_places_on_geom", using: :gist
  end

  create_table "cartographic_states", primary_key: "gid", id: :integer, default: nil, force: :cascade do |t|
    t.string "geoid", limit: 2
    t.geometry "geom", limit: {srid: 4326, type: "multi_polygon"}
    t.string "name"
    t.string "statefp", limit: 2
    t.string "stusps", limit: 2
    t.index ["geom"], name: "index_cartographic_states_on_geom", using: :gist
  end

  create_table "data_imports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "file_url", null: false
    t.datetime "imported_at", null: false
    t.datetime "updated_at", null: false
    t.index ["file_url"], name: "index_data_imports_on_file_url"
  end

  create_table "demographics", force: :cascade do |t|
    t.decimal "age_over_61_rate", precision: 5, scale: 2
    t.decimal "age_under_5_rate", precision: 5, scale: 2
    t.decimal "aian_rate", precision: 5, scale: 2
    t.decimal "asian_rate", precision: 5, scale: 2
    t.decimal "bachelors_degree_rate", precision: 5, scale: 2
    t.decimal "black_rate", precision: 5, scale: 2
    t.datetime "created_at", null: false
    t.decimal "hispanic_rate", precision: 5, scale: 2
    t.integer "household_income_lowest_quintile"
    t.integer "median_household_income"
    t.decimal "mixed_race_rate", precision: 5, scale: 2
    t.string "most_common_rate_tier"
    t.decimal "napi_rate", precision: 5, scale: 2
    t.decimal "no_health_insurance_rate", precision: 5, scale: 2
    t.decimal "other_race_rate", precision: 5, scale: 2
    t.decimal "owner_rate", precision: 5, scale: 2
    t.decimal "poc_rate", precision: 5, scale: 2
    t.decimal "population_density"
    t.decimal "population_in_poverty_rate", precision: 5, scale: 2
    t.decimal "poverty_rate", precision: 5, scale: 2
    t.string "pwsid", null: false
    t.decimal "renter_rate", precision: 5, scale: 2
    t.integer "total_population"
    t.decimal "unemployment_rate", precision: 5, scale: 2
    t.datetime "updated_at", null: false
    t.decimal "water_rate_125_249", precision: 5, scale: 2
    t.decimal "water_rate_250_499", precision: 5, scale: 2
    t.decimal "water_rate_500_749", precision: 5, scale: 2
    t.decimal "water_rate_750_999", precision: 5, scale: 2
    t.decimal "water_rate_over_1000", precision: 5, scale: 2
    t.decimal "water_rate_under_125", precision: 5, scale: 2
    t.decimal "white_rate", precision: 5, scale: 2
    t.index ["pwsid"], name: "index_demographics_on_pwsid", unique: true
  end

  create_table "environmental_justices", force: :cascade do |t|
    t.decimal "cejst_disadvantaged_pct", precision: 5, scale: 2
    t.integer "cejst_lead_paint_indicator"
    t.decimal "cejst_low_life_expectancy_pctl"
    t.datetime "created_at", null: false
    t.decimal "cvi_cancer_risk"
    t.decimal "cvi_life_expectancy"
    t.decimal "cvi_overall_score", precision: 5, scale: 2
    t.decimal "cvi_redlining"
    t.decimal "ejscreen_disability_rate"
    t.decimal "ejscreen_drinking_water"
    t.string "pwsid", null: false
    t.decimal "svi_overall_pctl", precision: 5, scale: 2
    t.datetime "updated_at", null: false
    t.index ["pwsid"], name: "index_environmental_justices_on_pwsid", unique: true
  end

  create_table "funding_summaries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "median_srf_assistance"
    t.string "pwsid", null: false
    t.integer "times_funded"
    t.decimal "total_principal_forgiveness"
    t.decimal "total_srf_assistance"
    t.datetime "updated_at", null: false
    t.index ["pwsid"], name: "index_funding_summaries_on_pwsid", unique: true
  end

  create_table "place_system_crosswalks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "fraction_of_place"
    t.decimal "fraction_of_service_area"
    t.string "geoid", limit: 7, null: false
    t.string "pwsid", null: false
    t.datetime "updated_at", null: false
    t.index ["geoid", "pwsid"], name: "index_place_system_crosswalks_on_geoid_and_pwsid", unique: true
    t.index ["pwsid"], name: "index_place_system_crosswalks_on_pwsid"
  end

  create_table "public_water_systems", primary_key: "pwsid", id: :string, force: :cascade do |t|
    t.decimal "area_sq_miles"
    t.text "counties"
    t.datetime "created_at", null: false
    t.string "detailed_facility_report"
    t.string "ewg_report_link"
    t.string "first_reported_date"
    t.string "gw_sw_code"
    t.boolean "is_grant_eligible"
    t.boolean "is_school_or_daycare"
    t.boolean "is_wholesaler"
    t.boolean "open_health_viol"
    t.string "owner_type"
    t.string "phone_number"
    t.string "pop_cat_5"
    t.integer "population_served_count"
    t.string "primacy_agency"
    t.string "primacy_type"
    t.string "primary_source_code"
    t.string "pws_name"
    t.string "service_area_type"
    t.integer "service_connections_count"
    t.boolean "source_water_protection_code"
    t.string "stusps", limit: 2
    t.string "symbology_field"
    t.datetime "updated_at", null: false
    t.integer "years_operating"
    t.index ["gw_sw_code"], name: "index_public_water_systems_on_gw_sw_code"
    t.index ["owner_type"], name: "index_public_water_systems_on_owner_type"
    t.index ["pop_cat_5"], name: "index_public_water_systems_on_pop_cat_5"
    t.index ["primacy_type"], name: "index_public_water_systems_on_primacy_type"
    t.index ["stusps"], name: "index_public_water_systems_on_stusps"
  end

  create_table "service_area_geometries", force: :cascade do |t|
    t.geometry "centroid", limit: {srid: 4326, type: "st_point"}
    t.datetime "created_at", null: false
    t.geometry "geom", limit: {srid: 4326, type: "multi_polygon"}
    t.string "geom_digest"
    t.geometry "geom_z0_4", limit: {srid: 4326, type: "multi_polygon"}
    t.geometry "geom_z5", limit: {srid: 4326, type: "multi_polygon"}
    t.geometry "geom_z6", limit: {srid: 4326, type: "multi_polygon"}
    t.geometry "geom_z7", limit: {srid: 4326, type: "multi_polygon"}
    t.string "pwsid", null: false
    t.datetime "updated_at", null: false
    t.index ["centroid"], name: "index_service_area_geometries_on_centroid", using: :gist
    t.index ["geom"], name: "index_service_area_geometries_on_geom", using: :gist
    t.index ["geom_digest"], name: "index_service_area_geometries_on_geom_digest"
    t.index ["pwsid"], name: "index_service_area_geometries_on_pwsid", unique: true
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "tile_cache", primary_key: ["layer", "z", "x", "y"], force: :cascade do |t|
    t.string "layer", null: false
    t.binary "mvt"
    t.integer "x", null: false
    t.integer "y", null: false
    t.integer "z", null: false
    t.index ["z", "x", "y"], name: "index_tile_cache_on_z_and_x_and_y"
  end

  create_table "trend_data", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "households_pct_change"
    t.string "income_change_flag"
    t.decimal "lowest_quintile_pct_change"
    t.decimal "mhi_pct_change"
    t.decimal "mhi_pct_change_capped"
    t.decimal "poc_pct_change"
    t.string "population_change_flag"
    t.decimal "population_in_poverty_pct_change"
    t.decimal "population_pct_change"
    t.decimal "population_pct_change_capped"
    t.decimal "poverty_pct_change"
    t.string "pwsid", null: false
    t.decimal "unemployment_pct_change"
    t.datetime "updated_at", null: false
    t.index ["pwsid"], name: "index_trend_data_on_pwsid", unique: true
  end

  create_table "violations_summaries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "groundwater_rule_10yr"
    t.integer "groundwater_rule_5yr"
    t.integer "health_violations_10yr"
    t.integer "health_violations_5yr"
    t.integer "inorganic_chemicals_10yr"
    t.integer "inorganic_chemicals_5yr"
    t.integer "lead_and_copper_10yr"
    t.integer "lead_and_copper_5yr"
    t.integer "paperwork_violations_10yr"
    t.integer "paperwork_violations_5yr"
    t.string "pwsid", null: false
    t.integer "radionuclides_10yr"
    t.integer "radionuclides_5yr"
    t.integer "stage_1_disinfectants_10yr"
    t.integer "stage_1_disinfectants_5yr"
    t.integer "stage_2_disinfectants_10yr"
    t.integer "stage_2_disinfectants_5yr"
    t.integer "surface_water_treatment_10yr"
    t.integer "surface_water_treatment_5yr"
    t.integer "synthetic_organic_chemicals_10yr"
    t.integer "synthetic_organic_chemicals_5yr"
    t.integer "total_coliform_10yr"
    t.integer "total_coliform_5yr"
    t.integer "total_violations_10yr"
    t.integer "total_violations_5yr"
    t.datetime "updated_at", null: false
    t.integer "violations_all_years"
    t.integer "volatile_organic_chemicals_10yr"
    t.integer "volatile_organic_chemicals_5yr"
    t.index ["pwsid"], name: "index_violations_summaries_on_pwsid", unique: true
  end

  create_table "watershed_hazards", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "impaired_streams_303d"
    t.integer "npdes_permits"
    t.integer "num_facilities"
    t.integer "open_underground_storage_tanks"
    t.integer "permit_effluent_violations"
    t.string "pwsid", null: false
    t.integer "risk_management_plan_facilities"
    t.datetime "updated_at", null: false
    t.index ["pwsid"], name: "index_watershed_hazards_on_pwsid", unique: true
  end

  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
