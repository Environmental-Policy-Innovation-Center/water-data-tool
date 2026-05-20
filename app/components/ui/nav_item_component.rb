class UI::NavItemComponent < ViewComponent::Base
  include ApplicationHelper

  NAV_ITEM_CLASSES = "nav-item w-full flex items-center gap-3 px-4 py-2.5 bg-white text-neutral-900 cursor-pointer " \
    "rounded-full border border-neutral-400 my-2 " \
    "md:hover:bg-neutral-200 md:hover:text-black " \
    "[&.active]:bg-brand-primary [&.active]:border-brand-primary [&.active]:text-white " \
    "group-data-[sidebar-collapsed]:w-10 " \
    "group-data-[sidebar-collapsed]:px-0 group-data-[sidebar-collapsed]:justify-center " \
    "group-data-[sidebar-collapsed]:border-0 group-data-[sidebar-collapsed]:rounded-lg " \
    "#{FOCUS_RING_CLASSES}"

  def initialize(label:, icon_name:, section: nil, href: nil, external: false, active: false)
    @label = label
    @icon_name = icon_name
    @section = section
    @href = href
    @external = external
    @active = active
  end

  def base_classes
    class_names(NAV_ITEM_CLASSES, @active && "active")
  end

  def link_classes
    class_names(NAV_ITEM_CLASSES, @active && "active", !(@external || mailto?) && "no-underline")
  end

  def accessible_label
    if @external
      "#{@label} (opens in new tab)"
    elsif mailto?
      "#{@label} (send email)"
    else
      @label
    end
  end

  def link?
    @href.present?
  end

  def mailto?
    @href.to_s.start_with?("mailto:")
  end
end
