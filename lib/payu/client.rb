module Payu
  # Stateless/reentrant facade over PayU's hosted-checkout + verify_payment
  # API. Construct once with credentials and reuse across requests.
  class Client
    def initialize(key:, salt:, test_mode: false)
      @config = Configuration.new
      @config.key = key
      @config.salt = salt
      @config.test_mode = test_mode
      @config.validate!
    end

    # Builds the signed hosted-checkout form. No network call is made —
    # only #verify_payment hits the network.
    def build_payment(txnid:, amount:, productinfo:, firstname:, email:, phone:,
                      surl:, furl:, notify_url: nil,
                      udf1: "", udf2: "", udf3: "", udf4: "", udf5: "")
      validate_build_payment!(txnid: txnid, amount: amount, email: email)

      amt = format("%.2f", amount)

      hash = Payu::Hash.request(
        key: @config.key, txnid: txnid, amount: amt,
        productinfo: productinfo, firstname: firstname, email: email,
        udf1: udf1, udf2: udf2, udf3: udf3, udf4: udf4, udf5: udf5,
        salt: @config.salt
      )

      fields = {
        key:         @config.key,
        txnid:       txnid,
        amount:      amt,
        productinfo: productinfo,
        firstname:   firstname,
        email:       email,
        phone:       phone.to_s,
        surl:        surl,
        furl:        furl,
        udf1:        udf1.to_s,
        udf2:        udf2.to_s,
        udf3:        udf3.to_s,
        udf4:        udf4.to_s,
        udf5:        udf5.to_s,
        hash:        hash
      }
      fields[:notify_url] = notify_url if notify_url && !notify_url.empty?

      PaymentForm.new(payment_url: @config.payment_url, fields: fields)
    end

    # Verifies an inbound callback/redirect's hash. Never raises on a bad
    # hash — the host decides how to record tampering via #valid?.
    #
    # PayU's reported status here is informational only — never trust it
    # for final state; always follow up with #verify_payment.
    def verify_callback(params)
      valid = Payu::Hash.valid_response?(params: params, salt: @config.salt)
      CallbackResult.new(params: params, valid: valid)
    end

    # Server-to-server reconciliation — the source of truth for transaction
    # state.
    def verify_payment(txnid:)
      hash = Payu::Hash.api(key: @config.key, command: "verify_payment", var1: txnid, salt: @config.salt)
      raw = Payu::Http.post_form(@config.api_url, command: "verify_payment", var1: txnid, hash: hash, key: @config.key)
      VerificationResult.new(txnid: txnid, raw: raw)
    end

    private

    def validate_build_payment!(txnid:, amount:, email:)
      raise Payu::ValidationError, "txnid is required" if txnid.to_s.strip.empty?
      raise Payu::ValidationError, "amount is required" if amount.nil?
      raise Payu::ValidationError, "email is required" if email.to_s.strip.empty?
    end
  end
end
