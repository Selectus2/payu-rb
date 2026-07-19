module Payu
  class Configuration
    attr_accessor :key, :salt, :test_mode

    # Production endpoints (docs.payu.in, confirmed May 2026)
    PAYMENT_URL  = "https://secure.payu.in/_payment"
    API_URL      = "https://secure.payu.in/merchant/postservice?form=2"

    # Sandbox endpoints
    TEST_PAYMENT_URL = "https://test.payu.in/_payment"
    TEST_API_URL     = "https://test.payu.in/merchant/postservice?form=2"

    def initialize
      @test_mode = false
    end

    def payment_url = test_mode ? TEST_PAYMENT_URL : PAYMENT_URL
    def api_url     = test_mode ? TEST_API_URL     : API_URL

    def validate!
      raise ConfigurationError, "Payu key is required"  if key.nil?  || key.empty?
      raise ConfigurationError, "Payu salt is required" if salt.nil? || salt.empty?
    end
  end
end
