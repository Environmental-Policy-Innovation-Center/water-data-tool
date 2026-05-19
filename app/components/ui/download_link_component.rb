class UI::DownloadLinkComponent < ViewComponent::Base
  include ApplicationHelper

  BASE_CLASSES = "inline-flex items-center gap-1.5 text-black font-bold"

  def initialize(url:, show_icon: true, classes: nil)
    @url = url
    @show_icon = show_icon
    @classes = classes
  end

  def call
    tag.a(href: @url, target: "_blank", rel: "noopener noreferrer",
      title: "Download file", download: true, class: class_names(BASE_CLASSES, @classes)) do
      parts = []
      parts << icon("downloads", classes: "w-4 h-4 shrink-0") if @show_icon
      parts << content
      parts << tag.span("(downloads file)", class: "sr-only")
      safe_join(parts)
    end
  end
end
