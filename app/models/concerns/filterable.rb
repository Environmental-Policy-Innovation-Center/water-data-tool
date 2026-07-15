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

    # Passthrough params with no owning manifest field.
    def apply_direct_filters(scope, params)
      scope = scope.where(stusps: params[:state]) if params[:state].present?
      scope
    end

    # OR within a category, AND across categories — see category_groups and docs/FILTERING.md.
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

    # Kept out of the generic path — needs tier slug → stored enum translation before hitting SQL.
    def apply_rate_tier_filter(scope, joined, params)
      tiers = Array(params[:most_common_rate_tier]).select(&:present?)
      return [scope, joined] if tiers.empty?

      scope, joined = left_join_once(scope, joined, :demographic)
      db_values = tiers.filter_map { |t| Demographic.most_common_rate_tiers[t] }
      [scope.where(Arel::Table.new(:demographics)[:most_common_rate_tier].in(db_values)), joined]
    end

    def apply_geographic_filters(scope, joined, params)
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

    # Grouped by layout category (OR within, AND across); ungrouped fields are singletons.
    # most_common_rate_tier is excluded — see apply_rate_tier_filter.
    def category_groups
      FieldRegistry.fields
        .select { |f| [:range, :bool, :radio, :multiselect].include?(f.filter_kind) }
        .reject { |f| f.key == :most_common_rate_tier }
        .group_by { |f| FilterLayout.category_of[f.key] }
        .flat_map { |category, fields| category ? [fields] : fields.zip }
    end

    def filter_active?(field, params)
      case field.filter_kind
      when :range then params[:"#{field.filter_param}_min"].present? || params[:"#{field.filter_param}_max"].present?
      when :bool then param_value(field, params) == bool_checked_value(field).to_s
      when :radio then param_value(field, params).present?
      when :multiselect then multiselect_values(field, params).any?
      end
    end

    def filter_predicate(field, params)
      case field.filter_kind
      when :range then range_predicate(field, params)
      when :bool then Arel::Table.new(field.table)[field.filter_column].eq(bool_checked_value(field))
      when :radio then Arel::Table.new(field.table)[field.filter_column].eq(param_value(field, params))
      when :multiselect then Arel::Table.new(field.table)[field.filter_column].in(multiselect_values(field, params))
      end
    end

    def param_value(field, params)
      params[field.filter[:param].to_sym]
    end

    def multiselect_values(field, params)
      Array(param_value(field, params)).select(&:present?)
    end

    # Defaults to real true; filter.checked_value overrides it for non-boolean columns.
    def bool_checked_value(field)
      field.filter[:checked_value] || true
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
