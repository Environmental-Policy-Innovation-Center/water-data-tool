class UI::FilterMenuComponentPreview < Lookbook::Preview
  # @label Default shell (menu 1)
  def default
    render(UI::FilterMenuComponent.new(menu_id: 1)) do
      tag.div(id: "container-menu-1-items", class: "p-4 text-sm text-neutral-700") do
        "Yielded filter fields would appear here."
      end
    end
  end

  # @label More menu (no main-filter-grp, Reset All)
  def more_menu
    render(UI::FilterMenuComponent.new(
      menu_id: 10,
      more_menu: true,
      reset_data_action: "click->filter#resetAll",
      reset_label: "Reset All"
    )) do
      tag.div(id: "container-menu-10-items", class: "p-4 text-sm text-neutral-700") do
        "More filters content."
      end
    end
  end
end
