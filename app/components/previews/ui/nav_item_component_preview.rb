class UI::NavItemComponentPreview < Lookbook::Preview
  # @label Button — inactive
  def default
    render UI::NavItemComponent.new(section: "datasets", label: "Datasets", icon_name: "data")
  end

  # @label Button — active (map on load)
  def active
    render UI::NavItemComponent.new(section: "map", label: "Explore the Map", icon_name: "explore", active: true)
  end

  # @label Button — downloads section
  def downloads
    render UI::NavItemComponent.new(section: "downloads", label: "Downloads", icon_name: "downloads")
  end

  # @label Button — table section
  def table
    render UI::NavItemComponent.new(section: "table", label: "Explore the Table", icon_name: "table")
  end

  # @label Link — external (Documentation)
  def external_link
    render UI::NavItemComponent.new(
      label: "Documentation",
      icon_name: "documentation",
      href: "https://example.com/methodology.pdf",
      external: true
    )
  end

  # @label Link — mailto (Contact EPIC)
  def mailto_link
    render UI::NavItemComponent.new(
      label: "Contact EPIC",
      icon_name: "email",
      href: "mailto:watertool@policyinnovation.org"
    )
  end
end
