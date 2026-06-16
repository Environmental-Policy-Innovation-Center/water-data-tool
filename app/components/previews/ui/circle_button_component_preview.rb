class UI::CircleButtonComponentPreview < Lookbook::Preview
  # @label Icon button (close)
  def icon_button
    render UI::CircleButtonComponent.new(aria_label: "Close") do
      "<svg class='h-4 w-4' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2'><path d='M18 6L6 18M6 6l12 12'/></svg>".html_safe
    end
  end

  # @label Text button (region shortcut)
  def text_button
    render UI::CircleButtonComponent.new(aria_label: "Zoom to Hawaii", data_action: "click->map#zoomHi", classes: "text-xs") do
      "HI"
    end
  end

  # @label With label on the left (toggle-all pattern)
  def labeled_left
    render UI::CircleButtonComponent.new(
      id: "preview-toggle-all",
      aria_label: "Toggle all columns",
      label: "Deselect all",
      label_position: :left
    ) do
      icon("checkbox-circle-on", classes: "size-4 text-neutral-900")
    end
  end

  # @label With label on the right
  def labeled_right
    render UI::CircleButtonComponent.new(
      aria_label: "Toggle all columns",
      label: "Select all",
      label_position: :right
    ) do
      icon("checkbox-circle-off", classes: "size-4 text-neutral-700")
    end
  end
end
