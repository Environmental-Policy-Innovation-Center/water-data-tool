module UrlStateCodecHelpers
  def encode_state(obj)
    Base64.urlsafe_encode64(Zlib::Deflate.deflate(JSON.generate(obj)), padding: false)
  end
end

RSpec.configure do |config|
  config.include UrlStateCodecHelpers
end
