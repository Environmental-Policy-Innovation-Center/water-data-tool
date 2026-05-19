class UI::ExternalLinkComponentPreview < Lookbook::Preview
  # @label Default (inline text link)
  def default
    render UI::ExternalLinkComponent.new(url: "https://example.com") do
      "documentation"
    end
  end

  # @label Custom color
  def custom_color
    render UI::ExternalLinkComponent.new(url: "https://example.com", classes: "text-brand-primary") do
      "methodology PDF"
    end
  end

  # @label No icon
  def no_icon
    render UI::ExternalLinkComponent.new(url: "https://example.com", show_icon: false) do
      "plain link"
    end
  end
end
