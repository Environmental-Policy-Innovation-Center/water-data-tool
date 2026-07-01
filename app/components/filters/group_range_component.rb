class Filters::GroupRangeComponent < ViewComponent::Base
  def initialize(checkbox_id:, panel_id:, label:, tooltip_text:, field:, min_input_id:, max_input_id:, group: nil, slider_label: "Number of violations", nested: false, format: nil)
    @checkbox_id = checkbox_id
    @panel_id = panel_id
    @label = label
    @tooltip_text = tooltip_text
    @field = field
    @min_input_id = min_input_id
    @max_input_id = max_input_id
    @group = group
    @slider_label = slider_label
    @nested = nested
    @format = format
  end

  # Range state derived from the URL for server-render.
  def min_value = helpers.filter_range_value(@field, :min)

  def max_value = helpers.filter_range_value(@field, :max)

  def active? = helpers.range_active?(@field)
end
