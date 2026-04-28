require "lograge/sql/extension"

Rails.application.configure do
  config.lograge.enabled = true
  config.action_view.logger = nil

  config.lograge.formatter = Class.new do
    def call(data)
      data.except(:format, :view, :allocations)
        .map { |k, v| "#{k}=#{v}" }
        .join(" ")
    end
  end.new

  config.lograge_sql.extract_event = proc do |event|
    next unless event.payload[:name].present?
    {name: event.payload[:name], duration: event.duration.to_f.round(2)}
  end

  config.lograge_sql.formatter = proc do |queries|
    queries.compact.map { |q| "#{q[:name]} (#{q[:duration]}ms)" }.join(", ")
  end

  config.lograge.custom_options = lambda do |event|
    {
      time: Time.current.iso8601,
      request_id: event.payload[:headers]["action_dispatch.request_id"],
      params: event.payload[:params].except("controller", "action", "format", "mvt").presence
    }.compact
  end
end
