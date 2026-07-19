# payu-ruby

Ruby client for the PayU India payment gateway — hosted-checkout form
building, callback/reverse-hash verification, server-to-server
`verify_payment` reconciliation, and refunds. Framework-agnostic; no Rails
dependency.

## Installation

```ruby
gem "payu-ruby"
```

## Usage

```ruby
client = Payu::Client.new(
  key:       "your_merchant_key",
  salt:      "your_merchant_salt",
  test_mode: true # use test.payu.in
)

# 1. Build the hosted-checkout redirect form (no network call)
form = client.build_payment(
  txnid:       "ORDER-123",
  amount:      499.00,
  productinfo: "Tickets for RubyConf",
  firstname:   "Jane",
  email:       "jane@example.com",
  phone:       "9876543210",
  surl:        "https://app.example.com/payu/callback",
  furl:        "https://app.example.com/payu/callback",
  notify_url:  "https://app.example.com/webhooks/payu"
)
form.payment_url # => URL to POST form.fields to (form submit or WebView)
form.fields      # => Hash of all form fields including :hash

# 2. Verify an inbound callback/redirect's hash.
# Never trust this alone for final state — see below.
callback = client.verify_callback(params)
callback.valid? # => true/false

# 3. Server-to-server reconciliation — the source of truth
result = client.verify_payment(txnid: "ORDER-123")
result.success? # / .pending? / .failed?
result.mihpayid
result.raw # full parsed JSON, for audit logging

# 4. Refunds
refund = Payu::Refund.new(key: "your_merchant_key", salt: "your_merchant_salt", test_mode: true)
refund.initiate(mihpayid: result.mihpayid, amount: 499.00)
refund.status(result.mihpayid)
```

**Security note**: `verify_callback` never raises on a bad hash — it returns
`valid?: false` so you decide how to record tampering. The callback's
reported status is informational only; always follow up with
`verify_payment` before treating a transaction as successful.

For Rails, expose `GET /checkout/:id/pay` that renders an auto-submit form
page. For mobile, return `{ payment_url:, params: }` as JSON and have the
app open `payment_url` in a WebView, POSTing the params.

## Error handling

All errors inherit from `Payu::PayuError`.

- `Payu::ConfigurationError` — missing `key`/`salt`.
- `Payu::ValidationError` — missing/blank required fields passed to
  `build_payment`.
- `Payu::ApiError` — base class for network/API failures; carries `#status`
  and `#body` when available.
  - `Payu::NetworkError` — no HTTP response was received (timeout,
    connection failure).
  - `Payu::ResponseError` — a response was received, but it was a non-200
    status or an unparseable body.

## Development

```
bundle install
bundle exec rspec
```

## License

MIT
