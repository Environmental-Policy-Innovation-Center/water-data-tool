class UI::ExternalLinkComponent < ViewComponent::Base
  include ApplicationHelper

  BASE_CLASSES = "inline-flex items-center gap-0.5"

  def initialize(url:, show_icon: true, underline: true, classes: nil, aria_label: nil)
    @url = url
    @show_icon = show_icon
    @underline = underline
    @classes = classes
    @aria_label = aria_label
  end

  def call
    tag.a(href: @url, target: "_blank", rel: "noopener noreferrer",
      title: "Opens in new tab", aria: {label: @aria_label},
      class: class_names(BASE_CLASSES, @underline && "underline", @classes)) do
      parts = []
      parts << content
      parts << icon("external-link", classes: "w-3.5 h-3.5 shrink-0") if @show_icon
      parts << tag.span("(opens in new tab)", class: "sr-only")
      safe_join(parts)
    end
  end
end
