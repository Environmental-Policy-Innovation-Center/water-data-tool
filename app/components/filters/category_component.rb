class Filters::CategoryComponent < ViewComponent::Base
  BASE_HEADING_CLASSES = "m-0 px-[15px] pt-3 text-base".freeze
  # Default: gray bar in its own panel; auto-switches to light when JS moves it into the More panel.
  DEFAULT_VARIANT_CLASSES = "font-medium text-white bg-[#989898] " \
    "[.filter-dropdown-more_&]:font-bold [.filter-dropdown-more_&]:text-neutral-900 [.filter-dropdown-more_&]:bg-white".freeze
  LIGHT_VARIANT_CLASSES = "font-bold text-neutral-900 bg-white".freeze

  def initialize(label:, variant: :default)
    @label = label
    @variant = variant
  end

  def heading_classes
    variant_classes = (@variant == :light) ? LIGHT_VARIANT_CLASSES : DEFAULT_VARIANT_CLASSES
    class_names(BASE_HEADING_CLASSES, variant_classes)
  end
end
