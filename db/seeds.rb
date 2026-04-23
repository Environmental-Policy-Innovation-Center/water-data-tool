# Production data is populated by the ETL pipeline (bin/rails etl:import).
# This file seeds sample data for local development only.
#
# Why not just call Etl::Importer directly?
# The ETL has no state-scoping — it imports the full national dataset, which is slow
# and impractical for dev resets. The seed task downloads the same S3 source files but
# filters to a small set of states and upserts directly, bypassing the staging/swap
# pattern the ETL uses for production atomicity. The trade-off is some duplicated field
# mapping logic between SeedImport (seed_states.rake) and Etl::FileImporter.
#
# Seeds states for broad filter coverage in local development:
#   VT + RI — small, fast to load, cover the common cases (~477 systems)
#   OH      — adds wholesaler and school/daycare systems (zero in VT/RI)
#   CO      — medium size, adds tribal systems (Ute) for tribal primacy/owner filters
#   PR      — territory primacy/owner type; only territory in the dataset with reliable data
#
# To seed different states: bin/rails 'db:seed:states[VT,RI,OH,CO,PR]'
if Rails.env.development?
  Rake::Task["db:seed:states"].invoke("VT", "RI", "OH", "CO", "PR")
end
