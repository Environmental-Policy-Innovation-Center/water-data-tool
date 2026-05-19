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
end
