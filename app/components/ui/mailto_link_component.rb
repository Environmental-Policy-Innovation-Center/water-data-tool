class UI::MailtoLinkComponent < ViewComponent::Base
  include ApplicationHelper

  BASE_CLASSES = "inline-flex items-center gap-0.5"

  def initialize(email:, show_icon: true, underline: true, classes: nil)
    raise ArgumentError, "Invalid email: #{email}" unless URI::MailTo::EMAIL_REGEXP.match?(email)

    @email = email
    @show_icon = show_icon
    @underline = underline
    @classes = classes
  end

  def call
    tag.a(href: "mailto:#{@email}", class: class_names(BASE_CLASSES, @underline && "underline", @classes)) do
      parts = []
      parts << content
      parts << icon("email", classes: "w-3.5 h-3.5 shrink-0") if @show_icon
      parts << tag.span("(send email)", class: "sr-only")
      safe_join(parts)
    end
  end
end
