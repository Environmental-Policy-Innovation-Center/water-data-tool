class UI::DownloadLinkComponentPreview < Lookbook::Preview
  # @label Default
  def default
    render UI::DownloadLinkComponent.new(url: "https://example.com/data.zip") do
      "National"
    end
  end

  # @label No icon
  def no_icon
    render UI::DownloadLinkComponent.new(url: "https://example.com/data.zip", show_icon: false) do
      "National"
    end
  end
end
