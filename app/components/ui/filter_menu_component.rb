class UI::FilterMenuComponent < ViewComponent::Base
  CONTAINER_BASE_CLASSES = "filter-dropdown filter-menu-scroll absolute top-[72px] z-[1001] " \
    "bg-white border-t-0 min-w-[350px] rounded-[15px] " \
    "shadow-[1px_4px_12px_rgba(51,51,51,0.3)] max-h-[calc(100vh-350px)] " \
    "[scrollbar-width:thin] [scrollbar-color:#b0b0b0_#f1f1f1] overflow-y-auto hidden"

  RESET_BUTTON_CLASSES = "inline-block cursor-pointer rounded-full border border-neutral-400 bg-white " \
    "px-7 py-2 text-sm text-neutral-800 no-underline mx-2 my-1.5 min-h-11 " \
    "hover:bg-neutral-200 hover:text-black #{ApplicationHelper::FOCUS_RING_CLASSES}"

  APPLY_BUTTON_CLASSES = "inline-block cursor-pointer rounded-full border border-brand-primary " \
    "bg-brand-primary px-7 py-2 text-sm text-white no-underline mx-2 my-1.5 min-h-11 " \
    "hover:brightness-110 #{ApplicationHelper::FOCUS_RING_CLASSES}"

  def initialize(menu_id:, more_menu: false, reset_data_action: "click->filter#reset", reset_label: "Reset")
    @menu_id = menu_id
    @more_menu = more_menu
    @reset_data_action = reset_data_action
    @reset_label = reset_label
  end

  def container_classes
    @more_menu ? "#{CONTAINER_BASE_CLASSES} filter-dropdown-more" : CONTAINER_BASE_CLASSES
  end
end
