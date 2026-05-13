class Filters::PopSizePillComponentPreview < Lookbook::Preview
  # @label Full segmented control (all five pills)
  def default
    render_with_template
  end

  # @label First pill
  def first
    render Filters::PopSizePillComponent.new(
      id: "preview-pop-very-small", label: "Very small", sublabel: "500 or less",
      pop_number: 1, position: :first
    )
  end

  # @label Middle pill
  def middle
    render Filters::PopSizePillComponent.new(
      id: "preview-pop-medium", label: "Medium", sublabel: "3,301 - 10,000",
      pop_number: 3
    )
  end

  # @label Last pill
  def last
    render Filters::PopSizePillComponent.new(
      id: "preview-pop-very-large", label: "Very large", sublabel: "100,000+",
      pop_number: 5, position: :last
    )
  end
end
