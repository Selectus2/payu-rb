require "spec_helper"

RSpec.describe Payu::PaymentForm do
  let(:payment_url) { "https://test.payu.in/_payment" }
  let(:fields) do
    {
      key: "gtKFFx", txnid: "ORD-001", amount: "499.00",
      productinfo: "Tickets <VIP>", firstname: "Jane & Bob", email: "jane@example.com",
      hash: "abc123"
    }
  end
  subject(:form) { described_class.new(payment_url: payment_url, fields: fields) }

  describe "#to_h" do
    it "returns payment_url and fields" do
      expect(form.to_h).to eq(payment_url: payment_url, fields: fields)
    end
  end

  describe "#to_html" do
    subject(:html) { form.to_html }

    it "posts to the payment_url" do
      expect(html).to include(%(action="#{payment_url}"))
      expect(html).to include('method="POST"')
    end

    it "auto-submits on load" do
      expect(html).to include("onload=")
      expect(html).to include("submit()")
    end

    it "includes a hidden input for every field" do
      fields.each do |name, value|
        expect(html).to include(%(name="#{name}"))
        expect(html).to include(%(value="#{CGI.escapeHTML(value.to_s)}"))
      end
    end

    it "HTML-escapes field values to prevent injection" do
      expect(html).to include("Tickets &lt;VIP&gt;")
      expect(html).to include("Jane &amp; Bob")
      expect(html).not_to include("<VIP>")
    end

    it "includes a noscript fallback" do
      expect(html).to include("<noscript>")
      expect(html).to include("<button")
    end
  end
end
