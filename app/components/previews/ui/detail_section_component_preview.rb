class UI::DetailSectionComponentPreview < Lookbook::Preview
  # @label Default (rows)
  def default
    render UI::DetailSectionComponent.new(
      title: "Overview",
      rows: [
        {label: "Population Served", value: "12,500"},
        {label: "Water Source", value: "Groundwater"},
        {label: "Owner Type", value: "Local Government"},
        {label: "Counties", value: "Dane"}
      ]
    )
  end

  # @label Data Not Available
  def data_not_available
    render UI::DetailSectionComponent.new(
      title: "Trends",
      data_available: false
    )
  end

  # @label Custom Content (block)
  def custom_content
    render UI::DetailSectionComponent.new(title: "Violations", data_available: true) do
      "<table class='w-full text-sm'>
        <tr class='border-b border-gray-100'><th class='py-1.5 text-left text-gray-500'></th><th class='py-1.5 text-left text-gray-500'>5-Year</th><th class='py-1.5 text-left text-gray-500'>10-Year</th></tr>
        <tr class='border-b border-gray-100'><td class='py-1.5 text-gray-500'>Health</td><td class='py-1.5 font-medium text-gray-800'>2</td><td class='py-1.5 font-medium text-gray-800'>4</td></tr>
        <tr><td class='py-1.5 text-gray-500 font-semibold'>Total</td><td class='py-1.5 font-semibold text-gray-800'>2</td><td class='py-1.5 font-semibold text-gray-800'>4</td></tr>
      </table>".html_safe
    end
  end
end
