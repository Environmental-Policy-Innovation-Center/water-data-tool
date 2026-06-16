module Etl
  ImportResult = Data.define(
    :file_key,
    :status,
    :changed_pwsids,
    :changed_layers,
    :geometry_changed,
    :full_refresh_required,
    :previous_geometry_bboxes
  ) do
    def self.imported(file_key:, changed_pwsids: [], changed_layers: [], geometry_changed: false, full_refresh_required: false, previous_geometry_bboxes: [])
      new(
        file_key: file_key,
        status: :imported,
        changed_pwsids: changed_pwsids.compact.uniq,
        changed_layers: changed_layers.compact.uniq,
        geometry_changed: geometry_changed,
        full_refresh_required: full_refresh_required,
        previous_geometry_bboxes: previous_geometry_bboxes.compact.uniq
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
        previous_geometry_bboxes: []
      )
    end

    def imported?
      status == :imported
    end

    def skipped?
      status == :skipped
    end

    def ==(other)
      return status == other if other.is_a?(Symbol)

      super
    end
  end
end
