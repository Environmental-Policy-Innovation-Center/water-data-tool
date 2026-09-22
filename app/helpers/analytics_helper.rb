module AnalyticsHelper
  # This helper hooks us up to the appropriate google analytics workstream & tags are not sensitive information
  GA_MEASUREMENT_ID = {
    "watertool.policyinnovation.info" => "G-SB89BG0GZ0",
    "water-data-tool-staging.policyinnovation.info" => "G-96SPRD0HTF"
  }.freeze

  def ga_measurement_id
    GA_MEASUREMENT_ID[request.host]
  end
end
