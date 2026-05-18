class UI::ExternalLinkComponent < ViewComponent::Base
  def initialize(url:, aria_label: nil, css_class: "underline")
    @url = url
    @aria_label = aria_label
    @css_class = css_class
  end

  def call
    tag.a(href: @url, target: "_blank", rel: "noopener noreferrer",
      title: "Opens in new tab", "aria-label": @aria_label, class: @css_class) do
      safe_join([content, tag.span("(opens in new tab)", class: "sr-only")])
    end
  end
end
