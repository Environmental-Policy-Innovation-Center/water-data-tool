class Filters::RateTierBtnComponent < ViewComponent::Base
  include ApplicationHelper

  BASE_CLASSES = "rate-tier-box flex-1 min-w-0 " \
    "border-y border-r border-neutral-400 " \
    "px-1.5 py-[10px] text-neutral-700 text-center text-[.8em] min-h-8 cursor-pointer " \
    "hover:bg-neutral-100 " \
    "[&.active]:bg-[#eff6ea] [&.active]:!text-black [&.active]:!border-l [&.active]:!border-[#66a03b] " \
    "#{FOCUS_RING_CLASSES}".freeze

  def initialize(id:, label:, value:, position: :middle, active: false)
    @id = id
    @label = label
    @value = value
    @position = position
    @active = active
  end

  def button_classes
    positioned = case @position
    when :first then class_names(BASE_CLASSES, "border-l rounded-l-[10px]")
    when :last then class_names(BASE_CLASSES, "rounded-r-[10px]")
    else BASE_CLASSES
    end
    class_names(positioned, "active" => @active)
  end
end
