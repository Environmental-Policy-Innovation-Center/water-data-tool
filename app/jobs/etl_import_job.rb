class EtlImportJob < ApplicationJob
  queue_as :default

  # Keyword arguments mirror the options exposed by the etl:import rake task.
  #
  #   EtlImportJob.perform_later                            # full import
  #   EtlImportJob.perform_later(only: "epa_sabs")         # single table
  #   EtlImportJob.perform_later(only: "epa_sabs", force: true)  # force re-import
  def perform(force: false, only: nil)
    manifest_url = ENV.fetch("ETL_MANIFEST_URL")
    Etl::Importer.new(manifest_url: manifest_url, force: force, only: only).call
  end
end
