module Payu
  # Return value of Client#verify_callback. Never raised on a bad hash —
  # #valid? reports the outcome so the host decides how to record tampering.
  #
  # This is informational only: PayU's reported status here must not be
  # trusted for final state. Always follow up with Client#verify_payment.
  class CallbackResult
    attr_reader :params, :valid

    def initialize(params:, valid:)
      @params = params
      @valid = valid
    end

    def valid? = @valid

    def txnid       = @params[:txnid]
    def status      = @params[:status]
    def email       = @params[:email]
    def firstname   = @params[:firstname]
    def productinfo = @params[:productinfo]
    def amount      = @params[:amount]
    def mihpayid    = @params[:mihpayid]

    def udf1 = @params[:udf1]
    def udf2 = @params[:udf2]
    def udf3 = @params[:udf3]
    def udf4 = @params[:udf4]
    def udf5 = @params[:udf5]
  end
end
