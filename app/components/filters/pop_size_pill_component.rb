class Filters::PopSizePillComponent < ViewComponent::Base
  include ApplicationHelper

  # pop-size-box and pop-size-N are JS hooks in filter_controller.js; pop-size-N is set in the template
  PILL_CLASSES = "pop-size-box " \
    "border-y border-r border-neutral-400 " \
    "px-2 py-[10px] text-neutral-700 text-center text-[.9em] min-h-8 cursor-pointer " \
    "hover:bg-neutral-100 " \
    "[&.active]:bg-[#eff6ea] [&.active]:!text-black [&.active]:!border-l [&.active]:!border-[#66a03b] " \
    "#{FOCUS_RING_CLASSES}"

  def initialize(id:, label:, sublabel:, pop_number:, position: :middle)
    @id = id
    @label = label
    @sublabel = sublabel
    @pop_number = pop_number
    @position = position
  end

  def pill_classes
    case @position
    when :first then "#{PILL_CLASSES} border-l border-neutral-400 rounded-l-[10px]"
    when :last then "#{PILL_CLASSES} rounded-r-[10px]"
    else PILL_CLASSES
    end
  end
end
