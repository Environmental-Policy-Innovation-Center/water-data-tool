class Report::HeaderComponentPreview < Lookbook::Preview
  def default
    pws = PublicWaterSystem.new(
      pws_name: "Clearwater Municipal Water District",
      pwsid: "CO0100123"
    )

    render Report::HeaderComponent.new(pws: pws)
  end
end
