# Lookbook previews for UI::DatasetCardComponent (datasets catalog).
#
# Behavior (see app/javascript/controllers/dataset_card_controller.js):
# - Body uses .dataset-card-body (max-height + overflow hidden in application.css).
# - A bottom sentinel drives clip detection; the footer button toggles show more / show less
#   via Stimulus (click->dataset-card#toggle). Button starts hidden until overflow is detected.
class UI::DatasetCardComponentPreview < Lookbook::Preview
  # @label Default
  def default
    render UI::DatasetCardComponent.new(
      title: "Safe Drinking Water Information System",
      source: "epa",
      source_name: "U.S. Environmental Protection Agency (EPA)",
      source_url: "https://www.epa.gov/ground-water-and-drinking-water/safe-drinking-water-information-system-sdwis-federal-reporting",
      frequency: "quarterly",
      date: "2026-02-20",
      description: "Water system violation, enforcement, and system information submitted by states and utilities.",
      caveats: [
        "Several variables in SDWIS reflect regulatory reporting structures rather than underlying infrastructure conditions",
        "Violations are known to be underreported and vary with enforcement practices"
      ]
    )
  end

  # @label Long body (likely clipped — show more / show less with JS)
  def long_content
    render UI::DatasetCardComponent.new(
      title: "Arkansas Drinking Water Advisories",
      source: "AR-Department-of-Health",
      source_name: "Arkansas Department of Health",
      source_url: "https://health.arkansas.gov/wa_engTraining/boilwaterorder.aspx",
      frequency: "quarterly",
      date: "2026-02-03",
      description: "Publicly available drinking water advisories for water systems located in Arkansas. " \
                   "Provided by the Arkansas Department of Health.",
      caveats: [
        "Data represents historical advisory events, not current drinking water conditions",
        "The official state site should be used for real-time public health information",
        "Advisories include precautionary notices such as boil water alerts, service interruptions, " \
          "and planned maintenance events, not just contamination incidents",
        "Please note there was a gap in our data collection from May 21st, 2025 to Feb 3rd, 2026",
        "It is assumed that a system would have maximum one advisory on a given day, and advisories " \
          "that have been edited by the state are considered a distinct advisory"
      ]
    )
  end

  # @label Compact (usually fits — toggle stays hidden with JS)
  def compact
    render UI::DatasetCardComponent.new(
      title: "Sample quarterly extract",
      source: "example",
      source_name: "Example Agency",
      source_url: "https://example.org/datasets/water",
      frequency: "quarterly",
      date: "2026-01-15",
      description: "Short description that fits within the card body.",
      caveats: [
        "Single caveat for preview purposes."
      ]
    )
  end

  # @label Static frequency
  def static_frequency
    render UI::DatasetCardComponent.new(
      title: "Texas Drinking Water Advisories",
      source: "TCEQ",
      source_name: "Texas Commission on Environmental Quality (TCEQ)",
      source_url: "https://www.tceq.texas.gov/",
      frequency: "static",
      date: "2024-04-17",
      description: "FOIA'd drinking water advisories for water systems located in Texas.",
      caveats: [
        "Data represents historical advisory events, not current drinking water conditions",
        "Please note this dataset only contains records from 2018 - 2024 from a FOIA request"
      ]
    )
  end
end
