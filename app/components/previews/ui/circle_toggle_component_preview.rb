class UI::CircleToggleComponentPreview < Lookbook::Preview
  # @label With label — checked (Deselect all)
  def with_label_checked
    render UI::CircleToggleComponent.new(
      id: "preview-toggle-checked",
      label: "Deselect all",
      checked: true
    )
  end

  # @label With label — unchecked (Select all)
  def with_label_unchecked
    render UI::CircleToggleComponent.new(
      id: "preview-toggle-unchecked",
      label: "Select all",
      checked: false
    )
  end

  # @label Icon only — with tooltip
  def icon_only
    render UI::CircleToggleComponent.new(
      id: "preview-toggle-icon",
      title: "Toggle selection",
      checked: true
    )
  end
end
