class UI::NavItemComponent < ViewComponent::Base
  include ApplicationHelper

  NAV_ITEM_CLASSES = "nav-item w-full flex items-center gap-3 px-4 py-2.5 bg-white text-neutral-900 cursor-pointer " \
    "rounded-full border border-neutral-400 my-2 " \
    "hover:bg-neutral-200 hover:text-black " \
    "[&.active]:bg-brand-primary [&.active]:border-brand-primary [&.active]:text-white " \
    "group-data-[sidebar-collapsed]:w-10 " \
    "group-data-[sidebar-collapsed]:px-0 group-data-[sidebar-collapsed]:justify-center " \
    "group-data-[sidebar-collapsed]:border-0 group-data-[sidebar-collapsed]:rounded-lg"

  def initialize(label:, icon_name:, section: nil, href: nil, external: false, active: false)
    @label = label
    @icon_name = icon_name
    @section = section
    @href = href
    @external = external
    @active = active
  end

  def base_classes
    @active ? "#{NAV_ITEM_CLASSES} active" : NAV_ITEM_CLASSES
  end

  def link?
    @href.present?
  end
end
