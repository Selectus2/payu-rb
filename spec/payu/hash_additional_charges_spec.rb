require "spec_helper"
require "digest"

RSpec.describe Payu::Hash do
  let(:key)  { "test-key" }
  let(:salt) { "test-salt" }

  let(:callback_params) do
    {
      "status"      => "success",
      "udf1"        => "",
      "udf2"        => "",
      "udf3"        => "",
      "udf4"        => "",
      "udf5"        => "",
      "email"       => "buyer@example.com",
      "firstname"   => "Jane",
      "productinfo" => "Tickets for Concert",
      "amount"      => "500.00",
      "txnid"       => "ORD-123-abcd",
      "key"         => key
    }
  end

  let(:base_string) do
    "#{salt}|success|||||||||||buyer@example.com|Jane|Tickets for Concert|500.00|ORD-123-abcd|#{key}"
  end

  let(:plain_hash)    { Digest::SHA512.hexdigest(base_string) }
  let(:surcharge)     { "12.50" }
  let(:prefixed_hash) { Digest::SHA512.hexdigest("#{surcharge}|#{base_string}") }

  describe ".response_candidates" do
    it "returns only plain when no additionalCharges" do
      candidates = described_class.response_candidates(params: callback_params, salt: salt)
      expect(candidates.keys).to eq(["plain"])
      expect(candidates["plain"]).to eq(plain_hash)
    end

    it "returns both forms when additionalCharges present (camelCase key)" do
      params = callback_params.merge("additionalCharges" => surcharge)
      candidates = described_class.response_candidates(params: params, salt: salt)
      expect(candidates.keys).to contain_exactly("plain", "additional_charges")
      expect(candidates["plain"]).to eq(plain_hash)
      expect(candidates["additional_charges"]).to eq(prefixed_hash)
    end

    it "handles snake_case key too" do
      params = callback_params.merge("additional_charges" => surcharge)
      candidates = described_class.response_candidates(params: params, salt: salt)
      expect(candidates.keys).to contain_exactly("plain", "additional_charges")
    end
  end

  describe ".valid_response?" do
    it "accepts plain hash when no surcharge" do
      params = callback_params.merge("hash" => plain_hash)
      expect(described_class.valid_response?(params: params, salt: salt)).to eq("plain")
    end

    it "accepts prefixed hash when surcharge present" do
      params = callback_params.merge("additionalCharges" => surcharge, "hash" => prefixed_hash)
      expect(described_class.valid_response?(params: params, salt: salt)).to eq("additional_charges")
    end

    it "accepts plain hash even when surcharge present (PayU edge case)" do
      params = callback_params.merge("additionalCharges" => surcharge, "hash" => plain_hash)
      expect(described_class.valid_response?(params: params, salt: salt)).to eq("plain")
    end

    it "rejects tampered hash" do
      params = callback_params.merge("additionalCharges" => surcharge, "hash" => "a" * 128)
      expect(described_class.valid_response?(params: params, salt: salt)).to be false
    end

    it "rejects wrong salt" do
      wrong = Digest::SHA512.hexdigest(base_string.sub(salt, "wrong-salt"))
      params = callback_params.merge("hash" => wrong)
      expect(described_class.valid_response?(params: params, salt: salt)).to be false
    end

    it "rejects missing hash" do
      expect(described_class.valid_response?(params: callback_params, salt: salt)).to be false
    end
  end
end
