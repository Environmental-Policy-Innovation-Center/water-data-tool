class UI::FilterMenuPanelComponentPreview < Lookbook::Preview
  # @label Default panel (menu 1 — Source)
  def default
    render_with_template
  end

  # @label More panel (collapsed categories auto-switch to light variant)
  def more_menu
    render_with_template
  end
end
