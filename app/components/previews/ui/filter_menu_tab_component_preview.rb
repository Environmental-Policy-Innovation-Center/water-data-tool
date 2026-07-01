class UI::FilterMenuTabComponentPreview < Lookbook::Preview
  # @label All tabs (nav bar context)
  def default
    render_with_template
  end

  # @label Single tab — Source
  def source
    render UI::FilterMenuTabComponent.new(menu_key: "source", label: "Source")
  end

  # @label Single tab — More
  def more
    render UI::FilterMenuTabComponent.new(menu_key: "more", label: "More")
  end
end
