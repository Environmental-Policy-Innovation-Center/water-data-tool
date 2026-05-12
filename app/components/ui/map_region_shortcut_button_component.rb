class UI::MapRegionShortcutButtonComponent < ViewComponent::Base
  FOCUS_RING = "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 " \
    "focus-visible:outline-blue-600 motion-reduce:transition-none"

  STATE_BUTTON_CLASSES =
    "block p-1.5 mt-[5px] text-[#333] text-[0.8em] rounded-full bg-white border border-[#bfbfbf] " \
    "text-center cursor-pointer hover:bg-[#f5f5f5] #{FOCUS_RING}".freeze

  TERRITORY_BUTTON_CLASSES =
    "block p-1.5 mt-[5px] text-[#666] text-[0.72em] rounded-full bg-white border border-[#bfbfbf] " \
    "text-center cursor-pointer hover:bg-[#f5f5f5] #{FOCUS_RING}".freeze

  def initialize(label:, aria_label:, map_action:, territory: false)
    @label = label
    @aria_label = aria_label
    @map_action = map_action
    @territory = territory
  end

  def button_classes
    @territory ? TERRITORY_BUTTON_CLASSES : STATE_BUTTON_CLASSES
  end

  def data_action
    "click->map##{@map_action}"
  end
end
