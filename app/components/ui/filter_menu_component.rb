class UI::FilterMenuComponent < ViewComponent::Base
  def initialize(menu_id:, more_menu: false, reset_data_action: "click->filter#reset", reset_label: "Reset")
    @menu_id = menu_id
    @more_menu = more_menu
    @reset_data_action = reset_data_action
    @reset_label = reset_label
  end

  def container_classes
    parts = [
      "container-menu",
      "filter-menu-scroll",
      "max-h-[calc(100vh-350px)]",
      "[scrollbar-width:thin]",
      "[scrollbar-color:#b0b0b0_#f1f1f1]",
      "overflow-y-auto",
      "hidden"
    ]
    parts << "container-menu-more" if @more_menu
    parts.join(" ")
  end
end
