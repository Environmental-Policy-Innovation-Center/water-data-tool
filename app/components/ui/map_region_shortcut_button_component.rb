class UI::MapRegionShortcutButtonComponent < ViewComponent::Base
  include ApplicationHelper

  BUTTON_CLASSES =
    "flex items-center justify-center w-[31px] h-[31px] mt-[5px] " \
    "rounded-full bg-white border border-[#bfbfbf] text-[#333] text-xs " \
    "cursor-pointer hover:bg-[#f5f5f5] #{FOCUS_RING_CLASSES}".freeze

  def initialize(label:, aria_label:, map_action:)
    @label = label
    @aria_label = aria_label
    @map_action = map_action
  end
end
