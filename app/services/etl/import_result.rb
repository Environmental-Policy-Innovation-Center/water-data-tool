module Etl
  ImportResult = Data.define(
    :file_key,
    :status,
    :changed_pwsids,
    :changed_layers,
    :geometry_changed,
    :full_refresh_required,
    :previous_geometry_bboxes,
    :changed_boundary_layers
  ) do
    def self.imported(file_key:, changed_pwsids: [], changed_layers: [], geometry_changed: false, full_refresh_required: false, previous_geometry_bboxes: [], changed_boundary_layers: [])
      new(
        file_key: file_key,
        status: :imported,
        changed_pwsids: changed_pwsids.compact.uniq,
        changed_layers: changed_layers.compact.uniq,
        geometry_changed: geometry_changed,
        full_refresh_required: full_refresh_required,
        previous_geometry_bboxes: previous_geometry_bboxes.compact.uniq,
        changed_boundary_layers: changed_boundary_layers.compact.uniq
      )
    end

    def self.skipped(file_key:)
      new(
        file_key: file_key,
        status: :skipped,
        changed_pwsids: [],
        changed_layers: [],
        geometry_changed: false,
        full_refresh_required: false,
        previous_geometry_bboxes: [],
        changed_boundary_layers: []
      )
    end

    def imported?
      status == :imported
    end

    def skipped?
      status == :skipped
    end
  end
end
