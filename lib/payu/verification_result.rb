module Payu
  # Return value of Client#verify_payment — the source of truth for
  # transaction state (never trust the callback/redirect alone).
  class VerificationResult
    attr_reader :raw, :txnid

    def initialize(txnid:, raw:)
      @txnid = txnid
      @raw = raw
    end

    def success? = transaction_status == "success"
    def pending? = transaction_status == "pending"
    def failed?  = !success? && !pending?

    def mihpayid     = transaction_details["mihpayid"]
    def bank_ref_num = transaction_details["bank_ref_num"]

    private

    def transaction_status
      transaction_details["status"]
    end

    def transaction_details
      @raw.dig("transaction_details", @txnid) || {}
    end
  end
end
