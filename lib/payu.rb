require "payu/version"
require "payu/errors"
require "payu/http"
require "payu/configuration"
require "payu/hash"
require "payu/payment_form"
require "payu/callback_result"
require "payu/verification_result"
require "payu/client"
require "payu/refund"

# Payu — Ruby client for PayU India payment gateway.
#
# Usage:
#   client = Payu::Client.new(
#     key:       "your_merchant_key",
#     salt:      "your_merchant_salt",
#     test_mode: true   # use test.payu.in
#   )
#
#   # 1. Build the hosted-checkout redirect form (no network call)
#   form = client.build_payment(
#     txnid:       "ORDER-123",
#     amount:      499.00,
#     productinfo: "Tickets for RubyConf",
#     firstname:   "Jane",
#     email:       "jane@example.com",
#     phone:       "9876543210",
#     surl:        "https://app.example.com/payu/callback",
#     furl:        "https://app.example.com/payu/callback",
#     notify_url:  "https://app.example.com/webhooks/payu"
#   )
#   form.payment_url  # => URL to POST form.fields to (form submit or WebView)
#   form.fields        # => Hash of all form fields including :hash
#   form.to_html        # => self-contained auto-submitting checkout page
#
#   # 2. Verify an inbound callback/redirect's hash (never trust it for final state)
#   callback = client.verify_callback(params)
#   callback.valid?  # => true/false
#
#   # 3. Server-to-server reconciliation — the source of truth
#   result = client.verify_payment(txnid: "ORDER-123")
#   result.success? / result.pending? / result.failed?
#   result.mihpayid
#   result.raw        # full parsed JSON, for audit logging
#
# form.to_html renders a complete auto-submitting checkout page — expose it
# from one GET route and that URL is all any client needs: redirect a
# browser to it, or point a mobile WebView at it. See README for details.
module Payu
end
