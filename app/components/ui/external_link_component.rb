class UI::ExternalLinkComponent < ViewComponent::Base
  include ApplicationHelper

  BASE_CLASSES = "inline-flex items-center gap-0.5"

  def initialize(url:, show_icon: true, classes: "underline")
    @url = url
    @show_icon = show_icon
    @classes = classes
  end

  def call
    tag.a(href: @url, target: "_blank", rel: "noopener noreferrer",
      title: "Opens in new tab", class: class_names(BASE_CLASSES, @classes)) do
      parts = []
      parts << content
      parts << icon("external-link", classes: "w-3.5 h-3.5 shrink-0") if @show_icon
      parts << tag.span("(opens in new tab)", class: "sr-only")
      safe_join(parts)
    end
  end
end
