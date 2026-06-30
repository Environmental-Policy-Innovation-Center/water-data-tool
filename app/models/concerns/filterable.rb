# frozen_string_literal: true

module Filterable
  extend ActiveSupport::Concern

  class_methods do
    def apply_filters(params)
      scope = all
      joined = Set.new

      scope = apply_direct_filters(scope, params)
      scope, joined = apply_category_filters(scope, joined, params)
      scope, joined = apply_rate_tier_filter(scope, joined, params)
      apply_geographic_filters(scope, joined, params)
    end

    private

    # Radio + multiselect filters. Each is its own single-filter category, so each ANDs (OR-of-one).
    def apply_direct_filters(scope, params)
      scope = scope.where(gw_sw_code: params[:gw_sw_code]) if params[:gw_sw_code].present?
      scope = scope.where(owner_type: params[:owner_type]) if params[:owner_type].present?
      scope = scope.where(primacy_type: params[:primacy_type]) if params[:primacy_type].present?
      scope = scope.where(pop_cat_5: params[:pop_cat_5]) if params[:pop_cat_5].present?
      scope = scope.where(symbology_field: params[:symbology_field]) if params[:symbology_field].present?
      scope = scope.where(stusps: params[:state]) if params[:state].present?
      scope
    end

    # Range + bool filters combined per the layout: filters within one category OR together (one
    # .where), and categories AND with one another. Column/table/coercion/join come from the manifest.
    # A field not surfaced in the layout (backend-only) is its own AND group. See docs/FILTERING.md.
    def apply_category_filters(scope, joined, params)
      category_groups.each do |fields|
        active = fields.select { |f| filter_active?(f, params) }
        next if active.empty?

        active.each { |f| scope, joined = ensure_join(scope, joined, f) }
        predicate = active.map { |f| filter_predicate(f, params) }.inject { |a, b| a.or(b) }
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

    # Range + bool fields grouped into OR-sets by layout category; a field not surfaced in the layout
    # (backend-only) is its own AND singleton.
    def category_groups
      FieldRegistry.fields
        .select { |f| [:range, :bool].include?(f.filter_kind) }
        .group_by { |f| FilterLayout.category_of[f.key] }
        .flat_map { |category, fields| category ? [fields] : fields.zip }
    end

    def filter_active?(field, params)
      case field.filter_kind
      when :range then params[:"#{field.filter_param}_min"].present? || params[:"#{field.filter_param}_max"].present?
      when :bool then params[field.filter[:param].to_sym] == "true"
      end
    end

    def filter_predicate(field, params)
      case field.filter_kind
      when :range then range_predicate(field, params)
      when :bool then Arel::Table.new(field.table)[field.filter_column].eq(true)
      end
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
