namespace :etl do
  desc <<~DESC
    Run the ETL import pipeline. Fetches the S3 manifest and imports any
    source files whose last_updated timestamp is newer than the last import.

    Usage:
      bin/rails etl:import                    # import all changed files
      bin/rails etl:import[epa_sabs]          # import a single table
      bin/rails etl:import[epa_sabs,force]    # force re-import regardless of timestamp
  DESC
  task :import, [:table, :mode] => :environment do |_, args|
    table = args[:table].presence
    force = args[:mode]&.strip&.downcase == "force"
    manifest_url = ENV.fetch("ETL_MANIFEST_URL")

    Etl::Importer.new(manifest_url: manifest_url, force: force, only: table).call

    puts "ETL import complete."
  end
end
