module AnalyticsHelper
  # This helper hooks us up to the appropriate google analytics workstream
  def ga_measurement_id
    if request.host.== "https://watertool.policyinnovation.info/"
      ENV["GA_MEASUREMENT_ID_PROD"]
    elsif request.host == "https://water-data-tool-staging.policyinnovation.info/"
      ENV["GA_MEASUREMENT_ID_STAGING"]
    end
  end
end
