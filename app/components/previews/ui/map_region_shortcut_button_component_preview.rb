class UI::MapRegionShortcutButtonComponentPreview < Lookbook::Preview
  # @label State — 48
  def state_48
    render UI::MapRegionShortcutButtonComponent.new(
      label: "48",
      aria_label: "Zoom to 48 states",
      map_action: "zoom48",
      territory: false
    )
  end

  # @label Territory — PR
  def territory_pr
    render UI::MapRegionShortcutButtonComponent.new(
      label: "PR",
      aria_label: "Zoom to Puerto Rico (territory)",
      map_action: "zoomPr",
      territory: true
    )
  end
end
