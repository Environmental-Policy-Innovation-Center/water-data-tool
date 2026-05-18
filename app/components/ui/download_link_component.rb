class UI::DownloadLinkComponent < ViewComponent::Base
  include ApplicationHelper

  def initialize(url:, show_icon: true, css_class: "inline-flex items-center gap-1.5 text-black font-bold")
    @url = url
    @show_icon = show_icon
    @css_class = css_class
  end

  def call
    tag.a(href: @url, target: "_blank", rel: "noopener noreferrer",
      title: "Download file", download: true, class: @css_class) do
      parts = []
      parts << icon("downloads", classes: "w-4 h-4 shrink-0") if @show_icon
      parts << content
      parts << tag.span("(download)", class: "sr-only")
      safe_join(parts)
    end
  end
end
