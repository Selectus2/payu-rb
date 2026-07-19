# Design Doc: Extracting PayU Hosted Checkout into a Ruby Gem (`payu_hosted`)

Status: Draft
Owner: TBD
Source implementation reviewed: `app/services/payu/payu_service.rb`, `app/jobs/check_payu_status_job.rb`, `app/controllers/payment_page_controller.rb`, `app/controllers/api/transactions_controller.rb`, `app/models/payment_transaction.rb`, `config/initializers/payu.rb`

## 1. Motivation

The PayU hosted-checkout integration (`Payu::PayuService`, gateway key `payu_hosted`) is currently coupled to this app's Mongoid models (`Receipt`, `Site`, `PaymentTransaction`), multi-tenant scoping (`Mongoid::Multitenancy`), and ENV-based config. Extracting it into a standalone gem gives us:

- A reusable, framework-agnostic client for PayU's hosted checkout + verify_payment API, usable outside this app or by other services.
- A clear seam between "PayU wire protocol" (hashing, form building, response verification) and "our domain" (Receipt/Site/AASM), which today are intermixed in one service class.
- A place to write the unit tests that currently don't exist for this integration at all.
- Independent versioning if PayU's API changes.

**Non-goals**: this gem will not replicate the legacy PayU Money / mobile-SDK flow (`transaction_service.rb`, `v2_transaction_service.rb`, gateway key `payu`) — that is a different product/hash scheme and out of scope. It also will not manage Rails-side persistence (`PaymentTransaction`, `Receipt` state machine) — the gem returns plain data; the host app decides what to persist and how to transition state.

## 2. Scope of behavior to port

Everything in `Payu::PayuService` is PayU wire-protocol logic and belongs in the gem:

| Capability | Current location | PayU API used |
|---|---|---|
| Build hosted-checkout form (params + hash) | `#initiate` + `#payment_hash` | Hosted checkout `_payment` form-post endpoint |
| Verify inbound callback signature | `#valid_reverse_hash?` + `#reverse_hash` | N/A (local hash check) |
| Server-to-server status/verify call | `#verify_payment` + `#verify_hash` | `verify_payment` command API |

Everything else (Redis caching of form data, `PaymentPageController`, AASM transitions on `Receipt`, `PaymentTransaction` persistence, `CheckPayuStatusJob` retry scheduling) stays in the host app, but the app-side code is rewritten to call the gem instead of duplicating hash logic.

## 3. Public API

```ruby
gem 'payu_hosted', '~> 0.1'
```

```ruby
client = PayuHosted::Client.new(
  key: creds[:key],
  salt: creds[:salt],
  sandbox: site.payment_gateways.dig('payu_hosted', 'sandbox') == true
)

# 1. Build the hosted-checkout redirect form
form = client.build_payment(
  txnid: receipt.id.to_s,
  amount: amount, # Numeric; gem formats to "%.2f"
  productinfo: 'simplysmart',
  firstname: resident.name,
  email: resident.email,
  phone: resident.mobile,
  surl: ENV.fetch('PAYU_CALLBACK_URL'),
  furl: ENV.fetch('PAYU_CALLBACK_URL'),
  udf1: receipt.id.to_s,
  udf2: receipt.receipt_number.to_s,
  udf3: resident.company.subdomain.to_s
)
form.payment_url   # => "https://secure.payu.in/_payment" (or test URL)
form.fields        # => Hash of all form fields including :hash, ready to render as hidden inputs

# 2. Verify an inbound callback/redirect and check tamper status
result = client.verify_callback(params) # params: Hash-like (ActionController::Parameters#to_unsafe_h or plain Hash)
result.valid?      # => true/false (hash matched)
result.txnid
result.status      # PayU's reported status string, informational only — do not trust for final state
result.udf1..udf5

# 3. Server-to-server reconciliation (the source of truth)
status = client.verify_payment(txnid: receipt.id.to_s)
status.success?
status.pending?
status.failed?
status.mihpayid
status.bank_ref_num
status.raw          # full parsed JSON response, for audit logging
```

Design choices:

- **`Client` is stateless/reentrant** per the current service object's usage pattern — constructed with credentials only, no receipt/session state, so one instance can be reused across requests (unlike today's `Payu::PayuService.new(receipt:, resident:, amount:)`).
- **No network calls in `build_payment`** — only `verify_payment` hits the network (via a small internal HTTP client, Faraday-based to avoid forcing HTTParty on consumers).
- **Sandbox/prod URL selection is internal** to the gem (`sandbox:` boolean), not left to the host app to pick `ENV['PAYU_PAYMENT_URL_SANDBOX']` vs `_PROD`. Default URLs are gem constants; overridable via `Client.new(..., payment_url:, verify_url:)` for hosts that need to override (matches today's per-site sandbox flag, generalized).
- **`verify_callback` never raises on bad hash** — it returns `valid?: false` so the host decides how to record "tampered" (today: `PaymentTransaction#status = 'tampered'` + `receipt.fail!`).
- **The gem does not decide success/failure from the callback alone** — this preserves the existing (correct) security property that only `verify_payment` is authoritative. The doc/readme must state this explicitly since it's easy for a future integrator to shortcut it.

## 4. Internals to port 1:1 (wire protocol — must not change semantics)

### 4.1 Request hash

```ruby
# key|txnid|amount|productinfo|firstname|email|udf1|udf2|udf3|udf4|udf5|||||salt
Digest::SHA512.hexdigest(
  [key, txnid, amount, productinfo, firstname, email, udf1, udf2, udf3, udf4, udf5, '', '', '', '', salt].join('|')
)
```

### 4.2 Reverse hash (callback verification)

```ruby
# salt|status|||||udf5|udf4|udf3|udf2|udf1|email|firstname|productinfo|amount|txnid|key
Digest::SHA512.hexdigest(
  [salt, status, '', '', '', '', '', udf5, udf4, udf3, udf2, udf1, email, firstname, productinfo, amount, txnid, key].join('|')
)
```
Must use `ActiveSupport::SecurityUtils.secure_compare` (or a vendored constant-time compare, e.g. `Rack::Utils.secure_compare`, to avoid pulling in Rails as a gem dependency) — never `==`.

### 4.3 Verify-payment hash

```ruby
# key|verify_payment|txnid|salt
Digest::SHA512.hexdigest("#{key}|verify_payment|#{txnid}|#{salt}")
```

These three formulas are copied verbatim from `payu_service.rb`; do not "clean up" the empty-pipe segments — they are positional placeholders for `udf6-10` required by PayU's spec.

## 5. Configuration surface

| Gem input | Maps from today's | Notes |
|---|---|---|
| `key`, `salt` | `Site#payment_gateway_credentials['payu']` | Passed explicitly to `Client.new`; gem has no knowledge of `Site` |
| `sandbox:` | `Site#payment_gateways.dig('payu_hosted','sandbox')` | Selects built-in test vs. live URLs |
| `payment_url:`, `verify_url:` (optional overrides) | `ENV['PAYU_PAYMENT_URL_*']`, `ENV['PAYU_VERIFY_URL_*']` | Default to PayU's documented sandbox/prod URLs baked into the gem; override only if PayU changes endpoints or for a mock server in tests |
| `surl`, `furl`, `udf1..udf5` | caller-supplied per call | Unchanged — remains host's responsibility to decide callback URL and metadata carried through the round trip |

Nothing from `config/initializers/payu.rb` (legacy `PAYU_CREDENTIALS`) or `config/payment_gateway.yml` moves into the gem — those are the legacy/UI concerns.

**Security note to fix during extraction, not after**: `config/initializers/payu.rb` currently contains hardcoded merchant key/salt values in source control. This gem effort is a natural point to also migrate the host app fully to per-site credentials sourced from an encrypted store and delete the hardcoded constants — flagged here so it isn't silently carried forward.

## 6. Host app integration changes

`Payu::PayuService` becomes a thin adapter over the gem:

```ruby
module Payu
  class PayuService
    def initiate
      creds = fetch_credentials
      client = PayuHosted::Client.new(key: creds[:key], salt: creds[:salt], sandbox: sandbox?)
      form = client.build_payment(txnid: @receipt.id.to_s, amount: @amount.to_f, ...)

      PaymentTransaction.create!(..., payment_request: form.fields.except(:hash))
      { payment_url: form.payment_url, form_data: form.fields, callback_ack_url: ENV.fetch('PAYU_ACK_URL') }
    end

    def process_callback(params)
      ...
      client = PayuHosted::Client.new(key: creds[:key], salt: creds[:salt], sandbox: sandbox?)
      callback = client.verify_callback(params)
      unless callback.valid?
        @payment_transaction&.update(status: 'tampered', resolved_at: Time.current)
        @receipt.fail!
        return @receipt.aasm_state
      end
      resolve_status(client.verify_payment(txnid: callback.txnid))
    end
  end
end
```

`CheckPayuStatusJob` similarly swaps its `Payu::PayuService#verify_payment_for_job` internals to call `client.verify_payment(txnid:)` and interpret `.success?`/`.pending?`/`.failed?`.

## 7. Gem project structure

```
payu_hosted/
├── lib/
│   ├── payu_hosted.rb
│   └── payu_hosted/
│       ├── client.rb
│       ├── payment_form.rb        # return value of #build_payment
│       ├── callback_result.rb     # return value of #verify_callback
│       ├── verification_result.rb # return value of #verify_payment
│       ├── hasher.rb              # the 3 SHA-512 formulas, isolated + unit-testable
│       ├── http.rb                # thin Faraday wrapper for verify_payment
│       └── errors.rb              # PayuHosted::Error, ::CredentialsError, ::NetworkError
├── spec/
│   ├── payu_hosted/
│   │   ├── client_spec.rb
│   │   ├── hasher_spec.rb         # golden-value tests against PayU's published sample hashes
│   │   └── ...
│   └── fixtures/verify_payment_responses/{success,pending,failure}.json
├── payu_hosted.gemspec
└── README.md
```

## 8. Testing plan (currently a gap — none exists today)

- `hasher_spec.rb`: golden-value tests for request hash, reverse hash, verify hash against fixed inputs (use PayU's published test vectors if available, otherwise hand-computed known-good values so a formula regression fails loudly).
- `client_spec.rb`: `build_payment` returns expected fields/URL for sandbox vs prod; `verify_callback` correctly flags tampered vs valid params; `verify_payment` parses success/pending/failure fixture JSON correctly, using WebMock to stub the HTTP call (mirroring the existing `spec/support/icici_merchant_stubs.rb` pattern from the host app).
- Contract test in the host app: after swapping `Payu::PayuService` to delegate to the gem, re-run/add specs asserting `initiate`, `process_callback`, and the retry job still produce identical `PaymentTransaction`/`Receipt` outcomes as before (since none exist today, this is also the first time this flow gets integration coverage).

## 9. Migration steps

1. Create gem (`bundle gem payu_hosted`), implement `Hasher`, `Client`, result objects, with unit tests as above.
2. Publish internally (private gem server or path/git dependency initially) and add to `Gemfile`.
3. Rewrite `Payu::PayuService` to delegate to `PayuHosted::Client`, keeping all `Receipt`/`PaymentTransaction`/AASM logic in the host.
4. Update `CheckPayuStatusJob` accordingly.
5. Add host-side specs (none exist — see §8) covering the new delegation.
6. Verify against PayU's sandbox environment end-to-end (initiate → redirect → callback → verify) before removing the old inline hash code.
7. Address the hardcoded-credentials issue in `config/initializers/payu.rb` as a follow-up (tracked separately, not blocking the gem extraction).

## 10. Known issues carried over from current implementation (to fix, not silently replicate)

- `CheckPayuStatusJob` calls `Notifier.payu_payment_failed(receipt)`, which is not defined in `app/mailers/notifier.rb` — will raise if the final-retry failure path is ever hit. Fix when rewiring the job, or make the failure hook a configurable callback the gem doesn't own.
- `payu.errors.*` I18n keys referenced in `fetch_credentials`/`validate_gateway!` are not defined in any locale file — replace with plain Ruby exception classes (`PayuHosted::CredentialsError`, etc.) that don't depend on I18n at all, removing this class of bug entirely.
