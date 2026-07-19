module Payu
  class PayuError         < StandardError; end
  class ConfigurationError < PayuError; end
  class HashMismatchError  < PayuError; end
  class PaymentFailedError < PayuError; end
  class ValidationError    < PayuError; end

  # Raised by Payu::Http. Carries the HTTP status and raw body when
  # available so callers can distinguish failure modes instead of pattern
  # matching on the message.
  class ApiError < PayuError
    attr_reader :status, :body

    def initialize(msg = nil, status: nil, body: nil)
      super(msg)
      @status = status
      @body = body
    end
  end

  # No HTTP response was received at all (timeout, connection refused, DNS, ...).
  class NetworkError < ApiError; end

  # A response was received, but it was a non-200 status or an unparseable body.
  class ResponseError < ApiError; end
end
