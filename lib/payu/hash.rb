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

    # Extract additionalCharges regardless of key style (camelCase or snake_case,
    # string or symbol). PayU sends camelCase in callbacks.
    def self.extract_additional_charges(params)
      val = params[:additionalCharges] || params["additionalCharges"] ||
            params[:additional_charges] || params["additional_charges"]
      v = val.to_s
      v.empty? ? nil : v
    end

    # Response hash candidates — returns a hash of candidate name => SHA512 digest.
    #
    # When additionalCharges is present, PayU may sign with either the plain or
    # prefixed form. Both candidates are returned so the caller can try each.
    #
    # Reverse hash formula (plain):
    #   sha512(SALT|status||||||udf5|udf4|udf3|udf2|udf1|email|firstname|productinfo|amount|txnid|key)
    #
    # Reverse hash formula (with additional charges):
    #   sha512(additionalCharges|SALT|status||||||udf5|udf4|udf3|udf2|udf1|email|firstname|productinfo|amount|txnid|key)
    def self.response_candidates(params:, salt:)
      p = params
      base_str = [
        salt,
        (p[:status] || p["status"]).to_s,
        "", "", "", "", "",
        (p[:udf5] || p["udf5"]).to_s,
        (p[:udf4] || p["udf4"]).to_s,
        (p[:udf3] || p["udf3"]).to_s,
        (p[:udf2] || p["udf2"]).to_s,
        (p[:udf1] || p["udf1"]).to_s,
        (p[:email] || p["email"]).to_s,
        (p[:firstname] || p["firstname"]).to_s,
        (p[:productinfo] || p["productinfo"]).to_s,
        (p[:amount] || p["amount"]).to_s,
        (p[:txnid] || p["txnid"]).to_s,
        (p[:key] || p["key"]).to_s
      ].join("|")

      charges = extract_additional_charges(params)
      candidates = { "plain" => Digest::SHA512.hexdigest(base_str) }
      candidates["additional_charges"] = Digest::SHA512.hexdigest("#{charges}|#{base_str}") if charges
      candidates
    end

    # Response hash — returns the expected reverse hash for verification.
    # When additionalCharges is present, returns the prefixed hash; otherwise plain.
    def self.response(params:, salt:)
      charges = extract_additional_charges(params)
      candidates = response_candidates(params: params, salt: salt)
      charges ? candidates["additional_charges"] : candidates["plain"]
    end

    # Constant-time comparison to prevent timing attacks.
    # Returns the matched form name ("plain" or "additional_charges") on success,
    # or false on failure. Truthy/falsy contract is preserved for backward compat.
    def self.valid_response?(params:, salt:)
      received = (params[:hash] || params["hash"]).to_s
      return false if received.empty?

      candidates = response_candidates(params: params, salt: salt)
      matched = candidates.find do |_name, expected|
        next false if expected.bytesize != received.bytesize
        expected.bytes.zip(received.bytes).reduce(0) { |acc, (a, b)| acc | (a ^ b) }.zero?
      end

      matched ? matched.first : false
    end

    # Hash for server-to-server API commands: sha512(key|command|var1|salt)
    def self.api(key:, command:, var1:, salt:)
      Digest::SHA512.hexdigest("#{key}|#{command}|#{var1}|#{salt}")
    end
  end
end
