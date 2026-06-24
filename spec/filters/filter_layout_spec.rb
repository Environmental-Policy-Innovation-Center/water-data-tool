# frozen_string_literal: true

require "rails_helper"

# Backstop for the placement split (CONFIG_AUDIT §8.4): config/filter_layout.yml is only safe as
# a second file with a spec proving it stays in lockstep with the manifest. Placement now lives
# ONLY in the layout (the interim menu/section tags were removed from fields.yml), so the invariant
# is membership: every surfaced filter appears in the layout exactly once, every backend-only filter
# stays out, and parent (grouping) keys are never themselves fields. Taxonomy (docs/FILTERING.md):
# menu → category → filter → sub-filter.
RSpec.describe FilterLayout do
  let(:filterable) { FieldRegistry.fields.select(&:filter) }
  let(:surfaced) { filterable.reject { |f| f.filter[:backend_only] } }
  let(:backend_only) { filterable.select { |f| f.filter[:backend_only] } }

  it "references every surfaced filter exactly once, and no others" do
    expect(FilterLayout.field_keys.sort).to eq(surfaced.map(&:key).sort)
  end

  it "keeps backend-only filters out of the layout" do
    expect(FilterLayout.field_keys & backend_only.map(&:key)).to be_empty
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
