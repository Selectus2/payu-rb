require "spec_helper"

RSpec.describe Payu::Http do
  let(:url) { "https://test.payu.in/merchant/postservice?form=2" }

  describe ".post_form" do
    it "returns parsed JSON on a 200 response" do
      stub_request(:post, url).to_return(status: 200, body: { "status" => 1 }.to_json)
      expect(described_class.post_form(url, command: "verify_payment")).to eq("status" => 1)
    end

    it "sends a payu-ruby User-Agent header" do
      stub_request(:post, url).to_return(status: 200, body: "{}")
      described_class.post_form(url, command: "verify_payment")
      expect(WebMock).to have_requested(:post, url).with(
        headers: { "User-Agent" => "payu-ruby/#{Payu::VERSION}; Ruby/#{RUBY_VERSION}" }
      )
    end

    it "raises ResponseError with status and body on a non-200 response" do
      stub_request(:post, url).to_return(status: 500, body: "<html>Internal Server Error</html>")
      expect { described_class.post_form(url, command: "verify_payment") }
        .to raise_error(Payu::ResponseError) { |e|
          expect(e.status).to eq(500)
          expect(e.body).to eq("<html>Internal Server Error</html>")
        }
    end

    it "raises ResponseError on an invalid JSON body" do
      stub_request(:post, url).to_return(status: 200, body: "not-json")
      expect { described_class.post_form(url, command: "verify_payment") }
        .to raise_error(Payu::ResponseError, /invalid JSON/)
    end

    it "raises NetworkError on a network/timeout failure" do
      stub_request(:post, url).to_raise(Net::OpenTimeout)
      expect { described_class.post_form(url, command: "verify_payment") }
        .to raise_error(Payu::NetworkError, /failed/)
    end

    it "NetworkError and ResponseError are both ApiError" do
      expect(Payu::NetworkError.ancestors).to include(Payu::ApiError)
      expect(Payu::ResponseError.ancestors).to include(Payu::ApiError)
    end
  end
end
