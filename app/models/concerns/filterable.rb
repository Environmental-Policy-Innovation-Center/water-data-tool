# frozen_string_literal: true

module Filterable
  extend ActiveSupport::Concern

  class_methods do
    def apply_filters(params)
      scope = all
      joined = Set.new

      scope = apply_direct_filters(scope, params)
      scope, joined = apply_area_filters(scope, joined, params)
      scope, joined = apply_violations_range_filters(scope, joined, params)
      scope, joined = apply_boil_water_filters(scope, joined, params)
      scope, joined = apply_demographic_filters(scope, joined, params)
      scope, joined = apply_environmental_justice_filters(scope, joined, params)
      scope, joined = apply_funding_filters(scope, joined, params)
      scope, joined = apply_watershed_hazard_filters(scope, joined, params)
      scope, joined = apply_trend_filters(scope, joined, params)
      apply_geographic_filters(scope, joined, params)
    end

    private

    def apply_direct_filters(scope, params)
      scope = scope.where(gw_sw_code: params[:gw_sw_code]) if params[:gw_sw_code].present?
      scope = scope.where(owner_type: params[:owner_type]) if params[:owner_type].present?
      scope = scope.where(primacy_type: params[:primacy_type]) if params[:primacy_type].present?
      scope = scope.where(pop_cat_5: params[:pop_cat_5]) if params[:pop_cat_5].present?
      scope = scope.where(symbology_field: params[:symbology_field]) if params[:symbology_field].present?

      scope = scope.where(is_wholesaler: true) if params[:is_wholesaler] == "true"
      scope = scope.where(is_school_or_daycare: true) if params[:is_school_or_daycare] == "true"
      scope = scope.where(source_water_protection_code: true) if params[:has_source_protection] == "true"
      scope = scope.where(open_health_viol: true) if params[:has_open_violations] == "true"

      scope = scope.where(stusps: params[:state]) if params[:state].present?
      scope
    end

    def apply_area_filters(scope, joined, params)
      # joined is unused here — area filters operate on public_water_systems directly.
      # Kept for interface consistency with other apply_* methods.
      scope = scope.where("area_sq_miles >= ?", params[:area_min].to_d) if params[:area_min].present?
      scope = scope.where("area_sq_miles <= ?", params[:area_max].to_d) if params[:area_max].present?
      [scope, joined]
    end

    def apply_violations_range_filters(scope, joined, params)
      paperwork_cols = FilterRegistry.paperwork_violation_columns
      subcat_5yr = FilterRegistry.health_subcat_5yr
      subcat_10yr = FilterRegistry.health_subcat_10yr

      violations_join_needed =
        paperwork_cols.any? { |col| params[:"#{col}_min"].present? || params[:"#{col}_max"].present? } ||
        (subcat_5yr + subcat_10yr).any? { |col| params[:"#{col}_min"].present? || params[:"#{col}_max"].present? }

      if violations_join_needed
        scope, joined = left_join_once(scope, joined, :violations_summary)
      end

      viol_table = Arel::Table.new(:violations_summaries)
      violation_group_where_clauses = []

      [subcat_5yr, subcat_10yr].each do |col_group|
        active = col_group.select { |col| params[:"#{col}_min"].present? || params[:"#{col}_max"].present? }
        next if active.empty?

        window_where_clause = active
          .map { |col| build_range_predicate(viol_table, col, params[:"#{col}_min"], params[:"#{col}_max"], coerce: :to_i) }
          .inject { |m, c| m.or(c) }
        violation_group_where_clauses << window_where_clause
      end

      paperwork_cols.each do |col|
        min_val = params[:"#{col}_min"]
        max_val = params[:"#{col}_max"]
        next unless min_val.present? || max_val.present?

        violation_group_where_clauses << build_range_predicate(viol_table, col, min_val, max_val, coerce: :to_i)
      end

      scope = scope.where(violation_group_where_clauses.inject { |m, c| m.or(c) }) if violation_group_where_clauses.any?
      [scope, joined]
    end

    def apply_boil_water_filters(scope, joined, params)
      if params[:boil_water_notices_min].present? || params[:boil_water_notices_max].present?
        scope, joined = left_join_once(scope, joined, :boil_water_summary)
        scope = scope.where("boil_water_summaries.total_notices >= ?", params[:boil_water_notices_min].to_i) if params[:boil_water_notices_min].present?
        scope = scope.where("boil_water_summaries.total_notices <= ?", params[:boil_water_notices_max].to_i) if params[:boil_water_notices_max].present?
      end
      [scope, joined]
    end

    def apply_demographic_filters(scope, joined, params)
      cols = FilterRegistry.demographic_range_columns

      demographic_cols_active = cols.any? { |col| params[:"#{col}_min"].present? || params[:"#{col}_max"].present? }
      demographic_cols_active ||= params[:density_min].present? || params[:density_max].present?
      demographic_cols_active ||= Array(params[:most_common_rate_tier]).any?(&:present?)

      if demographic_cols_active
        scope, joined = left_join_once(scope, joined, :demographic)
      end

      dem_t = Arel::Table.new(:demographics)
      # AND semantics: every active demographic constraint must be satisfied together.
      # Contrast with funding/hazard filters which OR across their columns.
      cols.each do |col|
        if params[:"#{col}_min"].present?
          scope = scope.where(dem_t[col].gteq(params[:"#{col}_min"].to_d))
        end
        if params[:"#{col}_max"].present?
          scope = scope.where(dem_t[col].lteq(params[:"#{col}_max"].to_d))
        end
      end

      scope = scope.where(dem_t[:population_density].gteq(params[:density_min].to_d)) if params[:density_min].present?
      scope = scope.where(dem_t[:population_density].lteq(params[:density_max].to_d)) if params[:density_max].present?

      tiers = Array(params[:most_common_rate_tier]).select(&:present?)
      if tiers.any?
        db_values = tiers.filter_map { |t| Demographic.most_common_rate_tiers[t] }
        scope = scope.where(dem_t[:most_common_rate_tier].in(db_values))
      end

      [scope, joined]
    end

    def apply_environmental_justice_filters(scope, joined, params)
      cols = FilterRegistry.environmental_justice_range_columns

      if cols.any? { |col| params[:"#{col}_min"].present? || params[:"#{col}_max"].present? }
        scope, joined = left_join_once(scope, joined, :environmental_justice)
      end

      ej_t = Arel::Table.new(:environmental_justices)
      cols.each do |col|
        if params[:"#{col}_min"].present?
          scope = scope.where(ej_t[col].gteq(params[:"#{col}_min"].to_d))
        end
        if params[:"#{col}_max"].present?
          scope = scope.where(ej_t[col].lteq(params[:"#{col}_max"].to_d))
        end
      end

      [scope, joined]
    end

    def apply_funding_filters(scope, joined, params)
      cols = FilterRegistry.funding_range_columns

      if cols.any? { |col| params[:"#{col}_min"].present? || params[:"#{col}_max"].present? }
        scope, joined = left_join_once(scope, joined, :funding_summary)
      end

      funding_table = Arel::Table.new(:funding_summaries)
      funding_where_clauses = cols.filter_map do |col|
        min_val = params[:"#{col}_min"]
        max_val = params[:"#{col}_max"]
        next unless min_val.present? || max_val.present?

        build_range_predicate(funding_table, col, min_val, max_val)
      end
      scope = scope.where(funding_where_clauses.inject { |m, c| m.or(c) }) if funding_where_clauses.any?

      [scope, joined]
    end

    def apply_watershed_hazard_filters(scope, joined, params)
      cols = FilterRegistry.watershed_hazard_range_columns

      if cols.any? { |col| params[:"#{col}_min"].present? || params[:"#{col}_max"].present? }
        scope, joined = left_join_once(scope, joined, :watershed_hazard)
      end

      hazard_table = Arel::Table.new(:watershed_hazards)
      hazard_where_clauses = cols.filter_map do |col|
        min_val = params[:"#{col}_min"]
        max_val = params[:"#{col}_max"]
        next unless min_val.present? || max_val.present?

        build_range_predicate(hazard_table, col, min_val, max_val, coerce: :to_i)
      end
      scope = scope.where(hazard_where_clauses.inject { |m, c| m.or(c) }) if hazard_where_clauses.any?

      [scope, joined]
    end

    def apply_trend_filters(scope, joined, params)
      cols = FilterRegistry.trend_range_columns

      if cols.any? { |col| params[:"#{col}_min"].present? || params[:"#{col}_max"].present? }
        scope, joined = left_join_once(scope, joined, :trend_datum)
      end

      trend_t = Arel::Table.new(:trend_data)
      cols.each do |col|
        if params[:"#{col}_min"].present?
          scope = scope.where(trend_t[col].gteq(params[:"#{col}_min"].to_d))
        end
        if params[:"#{col}_max"].present?
          scope = scope.where(trend_t[col].lteq(params[:"#{col}_max"].to_d))
        end
      end

      [scope, joined]
    end

    def apply_geographic_filters(scope, joined, params)
      if params[:place_geoid].present?
        pwsids = PlaceSystemCrosswalk.where(geoid: params[:place_geoid]).select(:pwsid)
        scope = scope.where(pwsid: pwsids)
      end

      if params[:county_geoid].present?
        scope = scope.where(<<~SQL.squish, params[:county_geoid])
          public_water_systems.pwsid IN (
            SELECT sag.pwsid
            FROM service_area_geometries sag
            JOIN cartographic_counties cc ON ST_Intersects(sag.centroid, cc.geom)
            WHERE cc.geoid = ?
          )
        SQL
      end

      if params[:bounds].present?
        west, south, east, north = params[:bounds].split(",").map(&:to_f)
        scope, _joined = left_join_once(scope, joined, :service_area_geometry)
        scope = scope.where(
          "ST_Intersects(service_area_geometries.geom, ST_MakeEnvelope(?, ?, ?, ?, 4326))",
          west, south, east, north
        )
      end

      scope
    end

    def build_range_predicate(arel_table, col, min_val, max_val, coerce: :to_d)
      arel_col = arel_table[col]
      if min_val.present? && max_val.present?
        arel_col.gteq(min_val.public_send(coerce)).and(arel_col.lteq(max_val.public_send(coerce)))
      elsif min_val.present?
        arel_col.gteq(min_val.public_send(coerce))
      else
        arel_col.lteq(max_val.public_send(coerce))
      end
    end

    def left_join_once(scope, joined, assoc)
      return [scope, joined] if joined.include?(assoc)

      [scope.left_joins(assoc), joined | [assoc]]
    end
  end
end
