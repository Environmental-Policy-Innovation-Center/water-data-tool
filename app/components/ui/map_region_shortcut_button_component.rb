class UI::MapRegionShortcutButtonComponent < ViewComponent::Base
  def initialize(label:, aria_label:, map_action:)
    @label = label
    @aria_label = aria_label
    @map_action = map_action
  end
end
