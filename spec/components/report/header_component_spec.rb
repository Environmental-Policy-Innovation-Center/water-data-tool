require "rails_helper"

RSpec.describe Report::HeaderComponent, type: :component do
  include ActiveSupport::Testing::TimeHelpers

  it "renders the utility name and system id" do
    pws = build(:public_water_system, pws_name: "Clearwater Co", pwsid: "CO1234567")

    render_inline described_class.new(pws: pws)

    expect(rendered_content).to include("Clearwater Co")
    expect(rendered_content).to include("CO1234567")
    expect(rendered_content).to include("Utility Report")
  end

  it "renders the generated date and time" do
    pws = build(:public_water_system)

    travel_to Time.zone.local(2026, 6, 3, 14, 5, 0) do
      render_inline described_class.new(pws: pws)

      expect(rendered_content).to include("6/3/2026")
      expect(rendered_content).to include("2:05 PM")
    end
  end

  it "renders the Drinking Water Explorer brand label" do
    pws = build(:public_water_system)

    render_inline described_class.new(pws: pws)

    expect(rendered_content).to include("Drinking")
    expect(rendered_content).to include("Water")
    expect(rendered_content).to include("Explorer")
  end
end
