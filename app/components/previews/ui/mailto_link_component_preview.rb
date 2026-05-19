class UI::MailtoLinkComponentPreview < Lookbook::Preview
  # @label Default (inline text link)
  def default
    render UI::MailtoLinkComponent.new(email: "watertool@policyinnovation.org") do
      "watertool@policyinnovation.org"
    end
  end

  # @label Label text
  def label_text
    render UI::MailtoLinkComponent.new(email: "watertool@policyinnovation.org") do
      "Contact EPIC"
    end
  end

  # @label No icon
  def no_icon
    render UI::MailtoLinkComponent.new(email: "watertool@policyinnovation.org", show_icon: false) do
      "watertool@policyinnovation.org"
    end
  end
end
