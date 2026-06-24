class Filters::CategoryComponent < ViewComponent::Base
  include ApplicationHelper

  BASE_HEADING_CLASSES = "m-0 px-[15px] py-5 text-base".freeze
  # Default: gray bar in its own panel; auto-switches to light when JS moves it into the More panel.
  DEFAULT_VARIANT_CLASSES = "font-medium text-white bg-[#989898] " \
    "[.filter-dropdown-more_&]:font-bold [.filter-dropdown-more_&]:text-neutral-900 [.filter-dropdown-more_&]:bg-white " \
    "[.filter-dropdown-more_&]:pt-3 [.filter-dropdown-more_&]:pb-0".freeze
  LIGHT_VARIANT_CLASSES = "font-bold text-neutral-900 bg-white".freeze

  def initialize(label:, variant: :default, tooltip_text: nil)
    @label = label
    @variant = variant
    @tooltip_text = tooltip_text
  end

  def tooltip?
    @tooltip_text.present?
  end

  def heading_classes
    variant_classes = (@variant == :light) ? LIGHT_VARIANT_CLASSES : DEFAULT_VARIANT_CLASSES
    class_names(BASE_HEADING_CLASSES, variant_classes)
  end
end
