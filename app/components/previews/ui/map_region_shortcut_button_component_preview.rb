class UI::MapRegionShortcutButtonComponentPreview < Lookbook::Preview
  # @label 48 states
  def state_48
    render UI::MapRegionShortcutButtonComponent.new(
      label: "48",
      aria_label: "Zoom to 48 states",
      map_action: "zoom48"
    )
  end

  # @label Territory — PR
  def territory_pr
    render UI::MapRegionShortcutButtonComponent.new(
      label: "PR",
      aria_label: "Zoom to Puerto Rico",
      map_action: "zoomPr"
    )
  end
end
