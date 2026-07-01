require "rails_helper"

# Backstop: config/table_layout.yml is the source of truth for which columns show. It may OMIT a
# manifest column (that column is just hidden), but every column it references must be a real
# manifest column (no typos) and appear at most once (no duplicate rendering).
RSpec.describe TableLayout do
  before { TableLayout.reload! }

  let(:manifest_keys) { FieldRegistry.display_field_keys }

  it "references only real manifest columns, each at most once" do
    expect(TableLayout.column_keys).to all(be_in(manifest_keys))
    expect(TableLayout.column_keys.uniq).to eq(TableLayout.column_keys)
  end

  # A layout column with a present-but-incomplete display block would otherwise blow up at
  # build time (missing :format) or render a blank header (missing :label) — caught here, not in the UI.
  it "gives every layout column a complete display block (a :format, plus a :label for all but the checkbox)" do
    by_key = FieldRegistry.by_key
    TableLayout.column_keys.each do |key|
      display = by_key[key]&.display
      expect(display).to be_present, "#{key} is in table_layout.yml but has no display block in fields.yml"
      expect(display[:format]).to be_present, "#{key} display block is missing :format"
      next if display[:format].to_s == "check" # the selection checkbox renders no header text
      expect(display[:label]).to be_present, "#{key} display block is missing :label"
    end
  end

  it "lists pinned columns that exist in the manifest and sit in no category" do
    expect(TableLayout.pinned_keys).to all(be_in(manifest_keys))
    TableLayout.pinned_keys.each { |key| expect(TableLayout.category_of[key]).to be_nil }
  end

  it "assigns every non-pinned column to a defined category" do
    category_keys = TableLayout.categories.map(&:key)
    (TableLayout.column_keys - TableLayout.pinned_keys).each do |key|
      expect(category_keys).to include(TableLayout.category_of[key])
    end
  end

  it "exposes categories as labeled CategoryDef records" do
    expect(TableLayout.categories).to all(be_a(CategoryDef))
    expect(TableLayout.categories.map(&:label)).to all(be_present)
  end

  describe "malformed config tolerance" do
    around do |example|
      example.run
    ensure
      TableLayout.reload!
    end

    it "does not crash on an empty/absent column list or pinned list" do
      allow(TableLayout).to receive(:config).and_return(
        pinned: nil,
        categories: {utility_details: {label: "Utility Details", columns: nil}}
      )
      TableLayout.reload!
      expect(TableLayout.column_keys).to eq([])
      expect(TableLayout.pinned_keys).to eq([])
      expect(TableLayout.category_of).to eq({})
    end
  end
end
