# frozen_string_literal: true

require "rails_helper"

# Backstop for the placement split (CONFIG_AUDIT §8.4): config/filter_layout.yml is only
# safe as a second file if a spec proves it stays in lockstep with the manifest. These
# examples assert the layout references every menu-tagged filter field exactly once and
# places each one where its manifest tags say it belongs — so when the interim tags are
# later removed from fields.yml, the layout has already been proven their faithful
# (ordered, nested) superset. Taxonomy (docs/FILTERING.md): menu → category → filter →
# sub-filter; the manifest's interim level-2 tag `section:` maps 1:1 to layout Category.
RSpec.describe FilterLayout do
  let(:menu_fields) { FieldRegistry.fields.select { |f| f.filter && f.filter[:menu] } }

  describe ".field_keys" do
    it "references each menu-tagged filter field exactly once (no orphans, no duplicates)" do
      expect(FilterLayout.field_keys.sort).to eq(menu_fields.map(&:key).sort)
    end
  end

  describe ".placements" do
    it "places every field in the menu and category its manifest tags declare" do
      tags_by_key = menu_fields.to_h { |f| [f.key, [f.filter[:menu].to_sym, f.filter[:section]&.to_sym]] }

      FilterLayout.placements.each do |p|
        expect([p.menu, p.category]).to eq(tags_by_key.fetch(p.key)),
          "#{p.key} sits under #{p.menu}/#{p.category} in the layout but is tagged #{tags_by_key[p.key].inspect} in the manifest"
      end
    end

    it "nests sub-filters only under parent filter keys that are not themselves manifest fields" do
      parents = FilterLayout.placements.filter_map(&:parent).uniq
      expect(parents & FieldRegistry.fields.map(&:key)).to be_empty
    end
  end
end
