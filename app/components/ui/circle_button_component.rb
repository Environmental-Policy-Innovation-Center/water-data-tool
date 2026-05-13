class UI::CircleButtonComponent < ViewComponent::Base
  include ApplicationHelper

  BASE_CLASSES = "flex items-center justify-center w-8 h-8 rounded-full bg-white " \
    "border border-neutral-300 text-[#444] cursor-pointer hover:bg-neutral-100 " \
    "#{FOCUS_RING_CLASSES}".freeze

  def initialize(aria_label:, data_action: nil, id: nil, extra_classes: nil)
    @aria_label = aria_label
    @data_action = data_action
    @id = id
    @extra_classes = extra_classes
  end

  def button_classes
    [BASE_CLASSES, @extra_classes].compact.join(" ")
  end
end
