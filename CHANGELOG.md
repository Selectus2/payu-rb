# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-07-19

Initial release.

### Added

- `Payu::Client#build_payment` — builds the signed hosted-checkout form
  (request hash + all required fields). No network call.
- `Payu::Client#verify_callback` — verifies an inbound callback/redirect's
  reverse hash using a constant-time comparison. Never raises on a bad
  hash; reports the outcome via `CallbackResult#valid?`.
- `Payu::Client#verify_payment` — server-to-server `verify_payment`
  reconciliation, the source of truth for transaction state.
- `Payu::Refund#initiate` / `Payu::Refund#status` — full/partial refund
  initiation and status lookup.
- Typed error hierarchy under `Payu::PayuError`: `ConfigurationError`,
  `ValidationError`, `ApiError` (with `NetworkError` and `ResponseError`
  subclasses carrying `#status` and `#body`).
- Framework-agnostic — no Rails dependency; works with Rails, Sinatra, or
  plain Ruby.
- Support for Ruby 3.1+, tested via CI against Ruby 3.1, 3.2, 3.3, and 3.4.
