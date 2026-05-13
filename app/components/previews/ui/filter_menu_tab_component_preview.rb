class UI::FilterMenuTabComponentPreview < Lookbook::Preview
  # @label All tabs (nav bar context)
  def default
    render_with_template
  end

  # @label Single tab — Source
  def source
    render UI::FilterMenuTabComponent.new(menu_id: 1, label: "Source")
  end

  # @label Single tab — More (menu 10)
  def more
    render UI::FilterMenuTabComponent.new(menu_id: 10, label: "More")
  end
end
