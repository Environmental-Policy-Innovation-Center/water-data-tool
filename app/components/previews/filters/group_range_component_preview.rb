class Filters::GroupRangeComponentPreview < Lookbook::Preview
  # @label Default (count scale — violations, funding, etc.)
  def default
    render Filters::GroupRangeComponent.new(
      checkbox_id: "preview-paperwork-5yr",
      panel_id: "preview-subcat-paperwork-5yr",
      label: "Non-health violations in the last 5 years",
      tooltip_text: "Violations related to reporting and monitoring requirements (paperwork), not contaminant levels.",
      field: "paperwork_violations_5yr",
      min_input_id: "preview-min-paperwork-5yr",
      max_input_id: "preview-max-paperwork-5yr",
      slider_label: "Number of violations"
    )
  end

  # @label Percent scale (demographics — poverty rate, unemployment, race/ethnicity, etc.)
  def percent
    render Filters::GroupRangeComponent.new(
      checkbox_id: "preview-poverty-rate",
      panel_id: "preview-subcat-poverty-rate",
      label: "Households below the poverty line",
      tooltip_text: "Percentage of households in the service area with income below the federal poverty line.",
      field: "poverty_rate",
      min_input_id: "preview-min-poverty-rate",
      max_input_id: "preview-max-poverty-rate",
      slider_label: "Percentage of households",
      format: "percent"
    )
  end

  # @label Percent change scale (trend data — signed, includes negatives, shows 0 midpoint)
  def percent_change
    render Filters::GroupRangeComponent.new(
      checkbox_id: "preview-pop-change",
      panel_id: "preview-subcat-pop-change",
      label: "Population change (10 years)",
      tooltip_text: "Percentage change in population served by this system over the past 10 years.",
      field: "population_pct_change_capped",
      min_input_id: "preview-min-pop-change",
      max_input_id: "preview-max-pop-change",
      slider_label: "Percentage change",
      format: "percent_change"
    )
  end

  # @label Currency scale (median household income, SRF assistance amounts)
  def currency
    render Filters::GroupRangeComponent.new(
      checkbox_id: "preview-median-income",
      panel_id: "preview-subcat-median-income",
      label: "Annual median household income",
      tooltip_text: "Median annual household income for the census tracts served by this system.",
      field: "median_household_income",
      min_input_id: "preview-min-median-income",
      max_input_id: "preview-max-median-income",
      slider_label: "Annual income",
      format: "currency"
    )
  end

  # @label Nested (health violation sub-category — inside an expanded parent panel)
  def nested
    render Filters::GroupRangeComponent.new(
      checkbox_id: "preview-groundwater-5yr",
      panel_id: "preview-subcat-groundwater-5yr",
      label: "Ground water rule",
      tooltip_text: "Violations of the Ground Water Rule, which sets standards for systems using ground water sources.",
      field: "groundwater_rule_5yr",
      min_input_id: "preview-min-groundwater-5yr",
      max_input_id: "preview-max-groundwater-5yr",
      slider_label: "Number of violations",
      nested: true
    )
  end
end
