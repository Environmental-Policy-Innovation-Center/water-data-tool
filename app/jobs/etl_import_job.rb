class EtlImportJob < ApplicationJob
  queue_as :default

  # Keyword arguments mirror the options exposed by the etl:import rake task.
  #
  #   EtlImportJob.perform_later                                 # full import
  #   EtlImportJob.perform_later(only: "epa_sabs")               # single table
  #   EtlImportJob.perform_later(only: "epa_sabs", force: true)  # force re-import
  def perform(force: false, only: nil)
    errors = Etl::Importer.new(force: force, only: only).call

    return if errors.empty?

    messages = errors.map { |e| "#{e[:file_key]}: #{e[:error].class} — #{e[:error].message}" }.join("; ")
    raise "ETL import completed with #{errors.length} failure(s): #{messages}"
  end
end
