module Payu
  class Refund
    def initialize(key:, salt:, test_mode: false)
      @config = Configuration.new
      @config.key = key
      @config.salt = salt
      @config.test_mode = test_mode
      @config.validate!
    end

    # Initiate a full or partial refund.
    # mihpayid: PayU's payment ID (returned in callback as :mihpayid)
    # amount:   amount to refund (can be partial)
    def initiate(mihpayid:, amount:)
      hash = Payu::Hash.api(
        key: @config.key, command: "cancel_refund_transaction",
        var1: mihpayid, salt: @config.salt
      )
      Payu::Http.post_form(
        @config.api_url,
        command: "cancel_refund_transaction", var1: mihpayid, var2: format("%.2f", amount),
        hash: hash, key: @config.key
      )
    end

    # Check refund status by mihpayid.
    def status(mihpayid)
      hash = Payu::Hash.api(
        key: @config.key, command: "get_refund_details",
        var1: mihpayid, salt: @config.salt
      )
      Payu::Http.post_form(
        @config.api_url,
        command: "get_refund_details", var1: mihpayid, hash: hash, key: @config.key
      )
    end
  end
end
