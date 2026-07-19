module Payu
  # Return value of Client#build_payment. No network call is made to
  # produce this — it's just the signed field set and the URL to post it to.
  class PaymentForm
    attr_reader :payment_url, :fields

    def initialize(payment_url:, fields:)
      @payment_url = payment_url
      @fields = fields
    end
  end
end
