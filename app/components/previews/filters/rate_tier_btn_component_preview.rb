class Filters::RateTierBtnComponentPreview < Lookbook::Preview
  # @label Full segmented control (all six tiers)
  def default
    render_with_template
  end

  # @label First pill
  def first
    render Filters::RateTierBtnComponent.new(id: "preview-rate-tier-lt125", label: "Under $125", position: :first)
  end

  # @label Middle pill
  def middle
    render Filters::RateTierBtnComponent.new(id: "preview-rate-tier-250-499", label: "$250–499")
  end

  # @label Last pill
  def last
    render Filters::RateTierBtnComponent.new(id: "preview-rate-tier-gt1000", label: "Over $1,000", position: :last)
  end
end
