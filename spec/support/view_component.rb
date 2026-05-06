require "view_component/test_helpers"

RSpec.configure do |config|
  config.include ViewComponent::TestHelpers, type: :component
  config.include(Module.new { def html = Nokogiri::HTML.parse(rendered_content) }, type: :component)
end
