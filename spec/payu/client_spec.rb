require "spec_helper"

RSpec.describe Payu::Client do
  let(:key)  { "gtKFFx" }
  let(:salt) { "eCwWELxi" }
  let(:client) { described_class.new(key: key, salt: salt, test_mode: true) }
  let(:api_url) { "https://test.payu.in/merchant/postservice?form=2" }

  describe "constructor validation" do
    it "raises ConfigurationError when key is missing" do
      expect { described_class.new(key: nil, salt: salt) }.to raise_error(Payu::ConfigurationError, /key/)
    end

    it "raises ConfigurationError when salt is missing" do
      expect { described_class.new(key: key, salt: nil) }.to raise_error(Payu::ConfigurationError, /salt/)
    end
  end

  describe "#build_payment" do
    let(:base_args) do
      {
        txnid: "ORD-001", amount: 499.0, productinfo: "Test Ticket",
        firstname: "Jane", email: "jane@example.com", phone: "9876543210",
        surl: "https://app.test/payu/success",
        furl: "https://app.test/payu/failure"
      }
    end
    subject(:form) { client.build_payment(**base_args) }

    it "returns a PaymentForm" do
      expect(form).to be_a(Payu::PaymentForm)
    end

    it "sets payment_url to the test URL when test_mode is true" do
      expect(form.payment_url).to eq("https://test.payu.in/_payment")
    end

    it "sets payment_url to the production URL when test_mode is false" do
      prod_client = described_class.new(key: key, salt: salt, test_mode: false)
      expect(prod_client.build_payment(**base_args).payment_url).to eq("https://secure.payu.in/_payment")
    end

    it "includes all mandatory PayU fields" do
      %i[key txnid amount productinfo firstname email phone surl furl hash].each do |field|
        expect(form.fields).to have_key(field)
      end
    end

    it "formats amount to 2 decimal places" do
      expect(form.fields[:amount]).to eq("499.00")
    end

    it "sets key from the client's credentials" do
      expect(form.fields[:key]).to eq(key)
    end

    it "includes a valid 128-char SHA-512 hash matching Payu::Hash.request" do
      expected = Payu::Hash.request(
        key: key, txnid: "ORD-001", amount: "499.00",
        productinfo: "Test Ticket", firstname: "Jane",
        email: "jane@example.com", salt: salt
      )
      expect(form.fields[:hash]).to eq(expected)
    end

    it "omits notify_url when not provided" do
      expect(form.fields).not_to have_key(:notify_url)
    end

    it "includes notify_url when provided" do
      f = client.build_payment(**base_args, notify_url: "https://app.test/webhooks/payu")
      expect(f.fields[:notify_url]).to eq("https://app.test/webhooks/payu")
    end

    it "does not make a network call" do
      expect(Net::HTTP).not_to receive(:new)
      form
    end

    it "raises ValidationError when txnid is blank" do
      expect { client.build_payment(**base_args, txnid: "") }.to raise_error(Payu::ValidationError, /txnid/)
    end

    it "raises ValidationError when amount is nil" do
      expect { client.build_payment(**base_args, amount: nil) }.to raise_error(Payu::ValidationError, /amount/)
    end

    it "raises ValidationError when email is blank" do
      expect { client.build_payment(**base_args, email: "  ") }.to raise_error(Payu::ValidationError, /email/)
    end
  end

  describe "#verify_callback" do
    let(:callback_params) do
      {
        key: key, txnid: "TXN123", amount: "499.00",
        productinfo: "Test Product", firstname: "Jane",
        email: "jane@example.com", status: "success",
        udf1: "", udf2: "", udf3: "", udf4: "", udf5: ""
      }
    end

    it "returns a CallbackResult" do
      expect(client.verify_callback(callback_params)).to be_a(Payu::CallbackResult)
    end

    it "is valid? when the hash matches" do
      correct_hash = Payu::Hash.response(params: callback_params, salt: salt)
      result = client.verify_callback(callback_params.merge(hash: correct_hash))
      expect(result.valid?).to be true
      expect(result.txnid).to eq("TXN123")
      expect(result.status).to eq("success")
    end

    it "is not valid? when the hash is tampered" do
      result = client.verify_callback(callback_params.merge(hash: "0" * 128))
      expect(result.valid?).to be false
    end

    it "is not valid? when the amount is tampered" do
      correct_hash = Payu::Hash.response(params: callback_params, salt: salt)
      tampered = callback_params.merge(amount: "1.00", hash: correct_hash)
      expect(client.verify_callback(tampered).valid?).to be false
    end

    it "does not raise on a bad hash" do
      expect { client.verify_callback(callback_params.merge(hash: "bad")) }.not_to raise_error
    end
  end

  describe "#verify_payment" do
    def stub_verify(status:)
      {
        "status" => status == "success" ? 1 : 0,
        "msg" => "Transaction Fetched Successfully",
        "transaction_details" => {
          "TXN123" => {
            "mihpayid" => "403993715523143",
            "status" => status,
            "amt" => "499.00",
            "mode" => "UPI",
            "bank_ref_num" => "123456789012"
          }
        }
      }.to_json
    end

    it "POSTs key, command, var1, and hash to the test API endpoint" do
      stub_request(:post, api_url).to_return(status: 200, body: stub_verify(status: "success"))
      client.verify_payment(txnid: "TXN123")
      expected_hash = Payu::Hash.api(key: key, command: "verify_payment", var1: "TXN123", salt: salt)
      expect(WebMock).to have_requested(:post, api_url).with(
        body: hash_including("command" => "verify_payment", "var1" => "TXN123", "hash" => expected_hash)
      )
    end

    it "returns a VerificationResult reporting success?" do
      stub_request(:post, api_url).to_return(status: 200, body: stub_verify(status: "success"))
      result = client.verify_payment(txnid: "TXN123")
      expect(result).to be_a(Payu::VerificationResult)
      expect(result.success?).to be true
      expect(result.pending?).to be false
      expect(result.failed?).to be false
      expect(result.mihpayid).to eq("403993715523143")
      expect(result.bank_ref_num).to eq("123456789012")
    end

    it "reports pending? for a pending transaction" do
      stub_request(:post, api_url).to_return(status: 200, body: stub_verify(status: "pending"))
      result = client.verify_payment(txnid: "TXN123")
      expect(result.pending?).to be true
      expect(result.success?).to be false
      expect(result.failed?).to be false
    end

    it "reports failed? for a failure/other status" do
      stub_request(:post, api_url).to_return(status: 200, body: stub_verify(status: "failure"))
      result = client.verify_payment(txnid: "TXN123")
      expect(result.failed?).to be true
      expect(result.success?).to be false
      expect(result.pending?).to be false
    end

    it "exposes the full parsed JSON via #raw" do
      stub_request(:post, api_url).to_return(status: 200, body: stub_verify(status: "success"))
      result = client.verify_payment(txnid: "TXN123")
      expect(result.raw["status"]).to eq(1)
    end

    it "raises NetworkError on network failure" do
      stub_request(:post, api_url).to_raise(Net::OpenTimeout)
      expect { client.verify_payment(txnid: "TXN123") }.to raise_error(Payu::NetworkError, /failed/)
    end

    it "raises ResponseError on invalid JSON response" do
      stub_request(:post, api_url).to_return(status: 200, body: "not-json")
      expect { client.verify_payment(txnid: "TXN123") }.to raise_error(Payu::ResponseError, /invalid JSON/)
    end

    it "raises ResponseError with status on a non-200 response" do
      stub_request(:post, api_url).to_return(status: 502, body: "Bad Gateway")
      expect { client.verify_payment(txnid: "TXN123") }.to raise_error(Payu::ResponseError) { |e|
        expect(e.status).to eq(502)
      }
    end
  end
end
