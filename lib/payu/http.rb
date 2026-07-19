require "net/http"
require "json"
require "uri"

module Payu
  # Thin internal POST wrapper shared by Client#verify_payment and Refund.
  # Not part of the public API.
  class Http
    USER_AGENT = "payu-ruby/#{Payu::VERSION}; Ruby/#{RUBY_VERSION}".freeze

    def self.post_form(url, params)
      uri  = URI(url)
      body = URI.encode_www_form(params)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = 30

      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/x-www-form-urlencoded"
      req["User-Agent"] = USER_AGENT
      req.body = body

      resp = http.request(req)

      unless resp.code.to_i == 200
        raise Payu::ResponseError.new(
          "PayU returned HTTP #{resp.code}", status: resp.code.to_i, body: resp.body
        )
      end

      begin
        JSON.parse(resp.body)
      rescue JSON::ParserError => e
        raise Payu::ResponseError.new(
          "PayU returned invalid JSON: #{e.message}", status: resp.code.to_i, body: resp.body
        )
      end
    rescue Payu::ApiError
      raise
    rescue => e
      raise Payu::NetworkError, "PayU API call failed: #{e.message}"
    end
  end
end
