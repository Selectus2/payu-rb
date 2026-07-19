require "spec_helper"

RSpec.describe Payu::Hash do
  let(:key)  { "gtKFFx" }
  let(:salt) { "eCwWELxi" }
  let(:base_params) do
    {
      key: key, txnid: "TXN123", amount: "499.00",
      productinfo: "Test Product", firstname: "Jane",
      email: "jane@example.com", salt: salt
    }
  end

  describe ".request" do
    it "returns a 128-character hex SHA-512 string" do
      result = described_class.request(**base_params)
      expect(result).to match(/\A[0-9a-f]{128}\z/)
    end

    it "includes all 17 pipe-delimited positions (6 mandatory + 5 UDF + 5 reserved + salt)" do
      # Build the preimage the same way the implementation does: 17 parts, pipe-joined
      parts = [
        "gtKFFx", "TXN123", "499.00", "Test Product", "Jane", "jane@example.com",
        "", "", "", "", "",   # udf1-5
        "", "", "", "", "",   # reserved slots
        "eCwWELxi"
      ]
      expected = Digest::SHA512.hexdigest(parts.join("|"))
      expect(described_class.request(**base_params)).to eq(expected)
    end

    it "incorporates udf fields when provided" do
      result_with_udf = described_class.request(**base_params, udf1: "EVENT-1")
      result_without  = described_class.request(**base_params)
      expect(result_with_udf).not_to eq(result_without)
    end

    it "is deterministic for the same input" do
      expect(described_class.request(**base_params)).to eq(described_class.request(**base_params))
    end
  end

  describe ".response" do
    let(:callback_params) do
      {
        key: key, txnid: "TXN123", amount: "499.00",
        productinfo: "Test Product", firstname: "Jane",
        email: "jane@example.com", status: "success",
        udf1: "", udf2: "", udf3: "", udf4: "", udf5: ""
      }
    end

    it "returns a 128-character hex SHA-512 string" do
      result = described_class.response(params: callback_params, salt: salt)
      expect(result).to match(/\A[0-9a-f]{128}\z/)
    end

    it "uses reversed field order vs request hash" do
      req_hash  = described_class.request(**base_params)
      resp_hash = described_class.response(params: callback_params, salt: salt)
      expect(req_hash).not_to eq(resp_hash)
    end

    it "prepends additional_charges when present" do
      without = described_class.response(params: callback_params, salt: salt)
      with_ac = described_class.response(
        params: callback_params.merge(additional_charges: "10.00"), salt: salt
      )
      expect(with_ac).not_to eq(without)
    end
  end

  describe ".valid_response?" do
    let(:callback_params) do
      {
        key: key, txnid: "TXN123", amount: "499.00",
        productinfo: "Test Product", firstname: "Jane",
        email: "jane@example.com", status: "success",
        udf1: "", udf2: "", udf3: "", udf4: "", udf5: ""
      }
    end

    it "returns true when hash matches" do
      correct_hash = described_class.response(params: callback_params, salt: salt)
      params_with_hash = callback_params.merge(hash: correct_hash)
      expect(described_class.valid_response?(params: params_with_hash, salt: salt)).to be true
    end

    it "returns false when hash is tampered" do
      params_with_bad_hash = callback_params.merge(hash: "0" * 128)
      expect(described_class.valid_response?(params: params_with_bad_hash, salt: salt)).to be false
    end

    it "returns false when amount is tampered" do
      correct_hash = described_class.response(params: callback_params, salt: salt)
      tampered = callback_params.merge(amount: "1.00", hash: correct_hash)
      expect(described_class.valid_response?(params: tampered, salt: salt)).to be false
    end
  end

  describe ".api" do
    it "returns sha512(key|command|var1|salt)" do
      expected = Digest::SHA512.hexdigest("gtKFFx|verify_payment|TXN123|eCwWELxi")
      expect(described_class.api(key: key, command: "verify_payment", var1: "TXN123", salt: salt)).to eq(expected)
    end
  end
end
