class UI::DatasetCardComponent < ViewComponent::Base
  def initialize(title:, source:, source_name:, source_url:, frequency:, date:, description:, caveats:)
    @title = title
    @source = source
    @source_name = source_name
    @source_url = source_url
    @frequency = frequency
    @date = Date.parse(date)
    @description = description
    @caveats = caveats
  end

  def formatted_date
    @date.strftime("%-m/%-d/%Y")
  end

  def frequency_label
    @frequency.capitalize
  end

  def iso_date
    @date.iso8601
  end
end
