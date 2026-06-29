# frozen_string_literal: true

module Filterable
  extend ActiveSupport::Concern

  class_methods do
    def apply_filters(params)
      scope = all
      joined = Set.new

      scope = apply_direct_filters(scope, params)
      scope, joined = apply_range_filters(scope, joined, params)
      scope, joined = apply_rate_tier_filter(scope, joined, params)
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

    # Combine every range filter per the layout: fields under a shared sub_filters parent OR, and
    # each group ANDs with the rest. Column/table/coercion/join come from the manifest. See
    # docs/FILTERING.md — sibling filters AND, sub_filters OR.
    def apply_range_filters(scope, joined, params)
      range_filter_groups.each do |fields|
        active = fields.select { |f| range_active?(f, params) }
        next if active.empty?

        active.each { |f| scope, joined = ensure_join(scope, joined, f) }
        predicate = active.map { |f| range_predicate(f, params) }.inject { |a, b| a.or(b) }
        scope = scope.where(predicate)
      end
      [scope, joined]
    end

    # Rate tier is a multiselect with bespoke value mapping (tier slug → stored enum), so it stays
    # out of the generic range applier. Its tiers OR; the filter ANDs with the rest.
    def apply_rate_tier_filter(scope, joined, params)
      tiers = Array(params[:most_common_rate_tier]).select(&:present?)
      return [scope, joined] if tiers.empty?

      scope, joined = left_join_once(scope, joined, :demographic)
      db_values = tiers.filter_map { |t| Demographic.most_common_rate_tiers[t] }
      [scope.where(Arel::Table.new(:demographics)[:most_common_rate_tier].in(db_values)), joined]
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

    # Range fields as OR-sets: one per sub_filters parent, plus a singleton per plain or
    # backend-only range field. Sets AND with one another.
    def range_filter_groups
      FieldRegistry.range_filter_fields
        .group_by { |f| FilterLayout.parent_of[f.key] }
        .flat_map { |parent, fields| parent ? [fields] : fields.zip }
    end

    def range_active?(field, params)
      params[:"#{field.filter_param}_min"].present? || params[:"#{field.filter_param}_max"].present?
    end

    def range_predicate(field, params)
      table = Arel::Table.new(field.table)
      coerce = (field.filter[:coercion].to_s == "integer") ? :to_i : :to_d
      build_range_predicate(table, field.filter_column, params[:"#{field.filter_param}_min"], params[:"#{field.filter_param}_max"], coerce: coerce)
    end

    def ensure_join(scope, joined, field)
      return [scope, joined] if field.model == :public_water_system
      left_join_once(scope, joined, field.model)
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
