require "rails_helper"

RSpec.describe Etl::ImportResult do
  it "normalizes changed pwsids and layers" do
    result = described_class.imported(
      file_key: "epa_sabs",
      changed_pwsids: ["A", nil, "A", "B"],
      changed_layers: ["pws", "pws", nil],
      previous_geometry_bboxes: [[-73, 44, -72, 45], nil, [-73, 44, -72, 45]]
    )

    expect(result.status).to eq(:imported)
    expect(result.changed_pwsids).to eq(%w[A B])
    expect(result.changed_layers).to eq(%w[pws])
    expect(result.previous_geometry_bboxes).to eq([[-73, 44, -72, 45]])
  end

  it "keeps symbol equality for existing importer specs and call sites" do
    expect(described_class.imported(file_key: "epa_sabs")).to eq(:imported)
    expect(described_class.skipped(file_key: "epa_sabs")).to eq(:skipped)
  end
end
