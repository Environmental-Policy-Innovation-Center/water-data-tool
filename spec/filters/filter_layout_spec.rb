# frozen_string_literal: true

require "rails_helper"

# Backstop for the placement split (CONFIG_AUDIT §8.4): config/filter_layout.yml is only safe as
# a second file with a spec proving its references resolve against the manifest. Placement lives
# ONLY in the layout. The invariant is ONE-DIRECTIONAL: every filter the layout references is a real
# filterable field, listed once — a typo'd or non-filterable reference would otherwise silently drop
# or 500. We do NOT require every filter to be placed; a filter absent from the layout is just
# URL-only. Parent (grouping) keys are never themselves fields. Taxonomy (docs/FILTERING.md):
# menu → category → filter → sub-filter.
RSpec.describe FilterLayout do
  let(:filterable) { FieldRegistry.fields.select(&:filter) }

  it "references only real filterable fields, each at most once" do
    layout_keys = FilterLayout.field_keys
    expect(layout_keys - filterable.map(&:key)).to be_empty
    expect(layout_keys).to eq(layout_keys.uniq)
  end

  it "nests sub-filters only under parent keys that are not themselves manifest fields" do
    parents = FilterLayout.placements.filter_map(&:parent).uniq
    expect(parents & FieldRegistry.fields.map(&:key)).to be_empty
  end

  # Tooltip refs (manifest filter tooltips + layout category/parent tooltips) must resolve to a
  # real key in tooltips.yml — a typo would otherwise silently render no tooltip.
  it "every filter tooltip references a real key in tooltips.yml" do
    valid = HomeHelper::FILTER_TOOLTIPS.keys.to_set
    manifest_refs = filterable.filter_map { |f| f.filter[:tooltip] }
    layout_refs = FilterLayout.menus.flat_map do |_menu_key, menu|
      menu.fetch(:categories).flat_map do |_category_key, category|
        parent_tips = category.fetch(:filters).filter_map { |f| f.values.first[:tooltip] if f.is_a?(Hash) }
        [category[:tooltip], *parent_tips]
      end
    end.compact

    unresolved = (manifest_refs + layout_refs).map(&:to_s).uniq.reject { |t| valid.include?(t) }
    expect(unresolved).to be_empty
  end
end
