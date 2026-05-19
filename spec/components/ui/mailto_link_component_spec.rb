require "rails_helper"

RSpec.describe UI::MailtoLinkComponent, type: :component do
  subject(:component) { described_class.new(email: "hello@example.com") }

  it "renders an anchor with a mailto href" do
    render_inline(component) { "Contact us" }
    expect(html.at_css("a")["href"]).to eq("mailto:hello@example.com")
  end

  it "always applies structural base classes" do
    render_inline(component) { "Contact us" }
    expect(html.at_css("a")["class"]).to include("inline-flex", "items-center", "gap-0.5")
  end

  it "is underlined by default" do
    render_inline(component) { "Contact us" }
    expect(html.at_css("a")["class"]).to include("underline")
  end

  it "yields content inside the anchor" do
    render_inline(component) { "Contact us" }
    expect(html.at_css("a").text).to include("Contact us")
  end

  it "includes sr-only send-email text" do
    render_inline(component) { "Contact us" }
    expect(html.at_css(".sr-only").text).to eq("(send email)")
  end

  it "does not set aria-label" do
    render_inline(component) { "Contact us" }
    expect(html.at_css("a")["aria-label"]).to be_nil
  end

  it "renders the email icon by default" do
    render_inline(component) { "Contact us" }
    expect(html.at_css("a svg")).to be_present
  end

  context "with show_icon: false" do
    subject(:component) { described_class.new(email: "hello@example.com", show_icon: false) }

    it "omits the icon" do
      render_inline(component) { "Contact us" }
      expect(html.at_css("a svg")).to be_nil
    end
  end

  context "with underline: false" do
    subject(:component) { described_class.new(email: "hello@example.com", underline: false) }

    it "omits the underline class" do
      render_inline(component) { "Contact us" }
      expect(html.at_css("a")["class"].split).not_to include("underline")
    end

    it "retains structural classes" do
      render_inline(component) { "Contact us" }
      expect(html.at_css("a")["class"]).to include("inline-flex", "items-center")
    end
  end

  context "with an invalid email" do
    it "raises ArgumentError" do
      expect {
        described_class.new(email: "not-an-email")
      }.to raise_error(ArgumentError, /Invalid email/)
    end
  end

  context "with custom classes" do
    subject(:component) { described_class.new(email: "hello@example.com", classes: "text-black font-bold underline") }

    it "merges custom classes with base classes" do
      render_inline(component) { "Contact us" }
      expect(html.at_css("a")["class"]).to include("inline-flex", "items-center", "text-black", "underline")
    end
  end
end
