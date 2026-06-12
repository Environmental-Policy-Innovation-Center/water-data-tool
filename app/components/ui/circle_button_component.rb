class UI::CircleButtonComponent < ViewComponent::Base
  include ApplicationHelper

  CIRCLE_CLASSES = "flex items-center justify-center w-8 h-8 rounded-full bg-white " \
    "border border-neutral-300 text-neutral-700 shrink-0".freeze

  BASE_CLASSES = "#{CIRCLE_CLASSES} cursor-pointer md:hover:bg-neutral-100 #{FOCUS_RING_CLASSES}".freeze

  LABELED_BUTTON_CLASSES = "inline-flex items-center gap-2 cursor-pointer " \
    "rounded #{FOCUS_RING_CLASSES}".freeze

  def initialize(aria_label:, data_action: nil, id: nil, classes: nil, label: nil, label_position: :right)
    @aria_label = aria_label
    @data_action = data_action
    @id = id
    @classes = classes
    @label = label
    @label_position = label_position
  end

  def button_classes
    if @label.present?
      class_names(LABELED_BUTTON_CLASSES, @classes)
    else
      class_names(BASE_CLASSES, @classes)
    end
  end

  def label_id
    "#{@id}-label" if @id && @label.present?
  end

  def label_html
    return "".html_safe unless @label.present?
    content_tag(:span, @label, class: "text-sm text-neutral-700", id: label_id)
  end
end
