class UI::FilterTabComponentPreview < Lookbook::Preview
  # @label Source tab
  def source
    render UI::FilterTabComponent.new(menu_id: 1, label: "Source", li_id: "source-filter-button")
  end

  # @label More tab (menu 10)
  def more
    render UI::FilterTabComponent.new(menu_id: 10, label: "More", li_id: "more-filter-button")
  end
end
