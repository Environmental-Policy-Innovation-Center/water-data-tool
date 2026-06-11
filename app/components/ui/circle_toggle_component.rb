class UI::CircleToggleComponent < ViewComponent::Base
  include ApplicationHelper

  PEER_FOCUS_CLASSES = FOCUS_RING_CLASSES
    .gsub("focus-visible:", "peer-focus-visible:")
    .sub("motion-reduce:transition-none", "peer-focus-visible:rounded-full")
    .freeze

  BASE_SVG_CLASSES = "size-4 shrink-0 #{PEER_FOCUS_CLASSES}".freeze

  def initialize(id:, checked: true, label: nil, title: nil, data_action: nil, input_classes: nil)
    @id = id
    @checked = checked
    @label = label
    @title = title
    @data_action = data_action
    @extra_input_classes = input_classes
  end

  def input_classes
    class_names(
      "peer absolute inset-0 w-full! h-full! opacity-0 cursor-pointer z-10",
      @extra_input_classes
    )
  end

  def off_svg_classes
    "#{BASE_SVG_CLASSES} text-neutral-700 peer-checked:hidden"
  end

  def on_svg_classes
    "#{BASE_SVG_CLASSES} text-neutral-900 hidden peer-checked:inline"
  end

  def label_id
    "#{@id}-txt"
  end
end
