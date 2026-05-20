class UI::FilterMenuTabComponent < ViewComponent::Base
  include ApplicationHelper

  FILTER_TAB_BUTTON_CLASSES = "filter-menu-btn flex h-10 w-auto items-center gap-2 px-4 py-2 cursor-pointer " \
    "bg-white text-neutral-900 rounded-full border border-neutral-400 " \
    "hover:bg-neutral-200 " \
    "[&.active]:bg-brand-primary [&.active]:border-brand-primary [&.active]:text-white " \
    "#{FOCUS_RING_CLASSES}".freeze

  def initialize(menu_id:, label:, mobile_label: nil)
    @menu_id = menu_id
    @label = label
    @mobile_label = mobile_label
  end
end
