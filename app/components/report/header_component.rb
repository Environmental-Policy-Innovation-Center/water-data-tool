class Report::HeaderComponent < ViewComponent::Base
  include ApplicationHelper

  def initialize(pws:)
    @pws = pws
  end

  def generated_at
    Time.current
  end

  def date_label
    generated_at.strftime("%-m/%-d/%Y")
  end

  def time_label
    generated_at.strftime("%l:%M %p").lstrip
  end
end
