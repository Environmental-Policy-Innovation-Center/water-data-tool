require "rails_helper"

RSpec.describe UrlStateCodec do
  describe ".decode" do
    it "decodes a valid compressed state" do
      state = {"nitrates_min" => "1", "nitrates_max" => "5", "cols" => "pwsid,name"}
      expect(described_class.decode(encode_state(state))).to eq(state)
    end

    it "handles arrays" do
      state = {"states" => ["TX", "CA"], "cols" => "pwsid"}
      expect(described_class.decode(encode_state(state))).to eq(state)
    end

    it "returns {} for nil" do
      expect(described_class.decode(nil)).to eq({})
    end

    it "returns {} for empty string" do
      expect(described_class.decode("")).to eq({})
    end

    it "returns {} for malformed base64" do
      expect(described_class.decode("!!!not-valid!!!")).to eq({})
    end

    it "returns {} for valid base64 but invalid zlib" do
      garbage = Base64.urlsafe_encode64("this is not zlib data", padding: false)
      expect(described_class.decode(garbage)).to eq({})
    end

    it "returns {} for valid zlib but invalid JSON" do
      bad_json = Base64.urlsafe_encode64(Zlib::Deflate.deflate("{{not json"), padding: false)
      expect(described_class.decode(bad_json)).to eq({})
    end
  end
end
