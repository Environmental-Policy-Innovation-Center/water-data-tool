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

    errors = Etl::Importer.new(force: force, only: table).call

    if errors.any?
      errors.each { |e| warn "[ETL] #{e[:file_key]} failed: #{e[:error].class} — #{e[:error].message}" }
      abort "ETL import completed with #{errors.length} failure(s)."
    else
      puts "ETL import complete."
    end
  end

  namespace :geometries do
    desc <<~DESC
      Backfill precomputed low-zoom service-area geometries.

      Usage:
        bin/rails etl:geometries:generalize
        PWSIDS=CA0000001,VT0000001 bin/rails etl:geometries:generalize
    DESC
    task generalize: :environment do
      pwsids = ENV.fetch("PWSIDS", "").split(",").map(&:strip).reject(&:blank?)
      Etl::PostImportSteps.generate_generalized_geometries(pwsids: pwsids.presence)
      Etl::PostImportSteps.analyze_spatial_tables
      puts "Generalized service-area geometries backfilled."
    end
  end
end
