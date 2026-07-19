require "digest"

module Payu
  module Hash
    # Request hash — confirmed formula from docs.payu.in (May 2026):
    #   sha512(key|txnid|amount|productinfo|firstname|email|udf1|udf2|udf3|udf4|udf5||||||SALT)
    # 17 pipe-delimited values: 6 mandatory + 5 UDF + 5 empty reserved slots + salt
    def self.request(key:, txnid:, amount:, productinfo:, firstname:, email:,
                     udf1: "", udf2: "", udf3: "", udf4: "", udf5: "", salt:)
      parts = [
        key, txnid, amount, productinfo, firstname, email,
        udf1.to_s, udf2.to_s, udf3.to_s, udf4.to_s, udf5.to_s,
        "", "", "", "", "",  # reserved udf6-udf10 slots
        salt
      ]
      Digest::SHA512.hexdigest(parts.join("|"))
    end

    # Response hash — field order is REVERSED vs request (confirmed from docs.payu.in):
    #   sha512(SALT|status||||||udf5|udf4|udf3|udf2|udf1|email|firstname|productinfo|amount|txnid|key)
    #
    # Variant: when PayU adds additional_charges (platform/convenience fee), it is prepended:
    #   sha512(additional_charges|SALT|status|...|key)
    def self.response(params:, salt:)
      p = params
      core = [
        salt,
        p[:status].to_s,
        "", "", "", "", "",  # reserved slots (reversed)
        p[:udf5].to_s, p[:udf4].to_s, p[:udf3].to_s, p[:udf2].to_s, p[:udf1].to_s,
        p[:email].to_s, p[:firstname].to_s, p[:productinfo].to_s,
        p[:amount].to_s, p[:txnid].to_s, p[:key].to_s
      ]
      additional = p[:additional_charges].to_s
      parts = additional.empty? ? core : [additional] + core
      Digest::SHA512.hexdigest(parts.join("|"))
    end

    # Constant-time comparison to prevent timing attacks
    def self.valid_response?(params:, salt:)
      expected = response(params: params, salt: salt)
      received = params[:hash].to_s
      return false if expected.bytesize != received.bytesize

      expected.bytes.zip(received.bytes).reduce(0) { |acc, (a, b)| acc | (a ^ b) }.zero?
    end

    # Hash for server-to-server API commands: sha512(key|command|var1|salt)
    def self.api(key:, command:, var1:, salt:)
      Digest::SHA512.hexdigest("#{key}|#{command}|#{var1}|#{salt}")
    end
  end
end
