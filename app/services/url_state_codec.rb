module UrlStateCodec
  def self.decode(str)
    return {} if str.blank?
    json = Zlib::Inflate.inflate(Base64.urlsafe_decode64(str))
    JSON.parse(json)
  rescue Zlib::Error, ArgumentError, JSON::ParserError
    {}
  end
end
