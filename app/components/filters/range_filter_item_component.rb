class Filters::RangeFilterItemComponent < ViewComponent::Base
  def initialize(checkbox_id:, panel_id:, label:, tooltip_text:, field:, min_input_id:, max_input_id:, slider_label: "Number of violations", nested: false, format: nil)
    @checkbox_id = checkbox_id
    @panel_id = panel_id
    @label = label
    @tooltip_text = tooltip_text
    @field = field
    @min_input_id = min_input_id
    @max_input_id = max_input_id
    @slider_label = slider_label
    @nested = nested
    @format = format
  end
end
