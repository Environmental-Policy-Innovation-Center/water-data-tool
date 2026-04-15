# Production data is populated by the ETL pipeline (bin/rails etl:import).
# This file seeds sample data for local development only.
#
# Seeds Vermont and Rhode Island — ~500 water systems total, enough to
# exercise all features locally. To seed different states, edit the invoke
# call below or run bin/rails 'db:seed:states[TX]' directly.
if Rails.env.development?
  Rake::Task["db:seed:states"].invoke("VT", "RI")
end
