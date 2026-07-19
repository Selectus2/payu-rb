require "spec_helper"

RSpec.describe Payu::Refund do
  let(:key)  { "gtKFFx" }
  let(:salt) { "eCwWELxi" }
  let(:refund) { described_class.new(key: key, salt: salt, test_mode: true) }
  let(:api_url) { "https://test.payu.in/merchant/postservice?form=2" }

  describe "#initiate" do
    it "POSTs the cancel_refund_transaction command with the correct hash" do
      stub_request(:post, api_url).to_return(status: 200, body: { "status" => 1 }.to_json)
      refund.initiate(mihpayid: "MIHPAY123", amount: 100.5)

      expected_hash = Payu::Hash.api(key: key, command: "cancel_refund_transaction", var1: "MIHPAY123", salt: salt)
      expect(WebMock).to have_requested(:post, api_url).with(
        body: hash_including(
          "command" => "cancel_refund_transaction", "var1" => "MIHPAY123", "var2" => "100.50", "hash" => expected_hash
        )
      )
    end

    it "returns the parsed JSON response" do
      stub_request(:post, api_url).to_return(status: 200, body: { "status" => 1, "msg" => "ok" }.to_json)
      expect(refund.initiate(mihpayid: "MIHPAY123", amount: 100.5)).to eq("status" => 1, "msg" => "ok")
    end
  end

  describe "#status" do
    it "POSTs the get_refund_details command with the correct hash" do
      stub_request(:post, api_url).to_return(status: 200, body: { "status" => 1 }.to_json)
      refund.status("MIHPAY123")

      expected_hash = Payu::Hash.api(key: key, command: "get_refund_details", var1: "MIHPAY123", salt: salt)
      expect(WebMock).to have_requested(:post, api_url).with(
        body: hash_including("command" => "get_refund_details", "var1" => "MIHPAY123", "hash" => expected_hash)
      )
    end

    it "returns the parsed JSON response" do
      stub_request(:post, api_url).to_return(status: 200, body: { "status" => 1 }.to_json)
      expect(refund.status("MIHPAY123")).to eq("status" => 1)
    end
  end
end
