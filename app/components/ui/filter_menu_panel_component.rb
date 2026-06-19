class UI::FilterMenuPanelComponent < ViewComponent::Base
  include ApplicationHelper

  CONTAINER_BASE_CLASSES = "filter-dropdown filter-menu-scroll absolute top-[72px] z-[1001] " \
    "bg-white border-t-0 rounded-[15px] " \
    "shadow-[1px_4px_12px_rgba(51,51,51,0.3)] max-h-[calc(100vh-350px)] " \
    "overflow-y-auto hidden".freeze

  FILTERS_MENU_MOBILE_CLASSES = "max-sm:!min-w-0 " \
    "max-sm:left-2 max-sm:right-2 max-sm:w-auto " \
    "max-sm:overflow-x-hidden max-sm:[scrollbar-gutter:stable]".freeze

  RESET_BUTTON_CLASSES = "inline-block cursor-pointer rounded-full border border-neutral-400 bg-white " \
    "px-7 py-2 text-sm text-neutral-800 no-underline mx-2 my-1.5 min-h-11 " \
    "md:hover:bg-neutral-200 md:hover:text-black #{FOCUS_RING_CLASSES}".freeze

  APPLY_BUTTON_CLASSES = "inline-block cursor-pointer rounded-full border border-brand-primary " \
    "bg-brand-primary px-7 py-2 text-sm text-white no-underline mx-2 my-1.5 min-h-11 " \
    "md:hover:brightness-110 #{FOCUS_RING_CLASSES}".freeze

  def initialize(menu_id:, more_menu: false, width_class: "w-[350px]", reset_data_action: "click->filter#reset", reset_label: "Reset")
    @menu_id = menu_id
    @more_menu = more_menu
    @width_class = width_class
    @reset_data_action = reset_data_action
    @reset_label = reset_label
  end

  def container_classes
    class_names(CONTAINER_BASE_CLASSES, @width_class, @more_menu && "filter-dropdown-more overflow-x-hidden #{FILTERS_MENU_MOBILE_CLASSES}")
  end
end
