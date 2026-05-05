# `appstoreconnect-smoke` CLI — Shaping Notes

## Scope

A new SPM `.executableTarget` named `appstoreconnect-smoke`, runnable via
`swift run`. Calls the wrapper's three repository methods in sequence
against the live App Store Connect API to confirm credentials work and
mapping handles real responses. Dev-only; not run in CI.

## Decisions

- **Target type:** SPM `.executableTarget`.
- **Argument parsing:** inline (no new dependency).
- **Credentials:** env vars by default, flags override. Both env and flag
  available for each value.
- **Private key:** path or inline string accepted; path takes precedence.
- **Target name:** `appstoreconnect-smoke`.
- **Pipeline:** one-shot — `fetchProfiles` → `fetchProfileDetails` →
  `fetchCertificate`. Picks `profiles[0]` and `details.certificates[0]`
  automatically; no flags to override choice in this iteration.
- **executor-cli:** unrelated; no shim added.
- **New public API:** `AppleDeveloper.Factory.make(...) -> any AppStoreConnectAPI`
  to hide `AppleDeveloperAPIDefault` from the executable. Closes the open
  goal in the `architecture/namespaced-factory` standard.
- **Output:** plain text to stdout. No JSON / verbose flags.
- **Exit codes:** 0 success, 1 runtime error, 2 usage error.

## Context

- **Visuals:** None.
- **References:** Existing wrapper in
  `Sources/AppleDeveloperAPI/AppleDeveloperAPI.swift` (Factory),
  `AppStoreConnectAPI.swift` (protocol), upstream SDK auth docs in
  the `appstoreconnect-swift-sdk` README.
- **Product alignment:** No `agent-os/product/` exists.

## Standards Applied

- `architecture/sdk-seam-isolation` — the executable depends on
  `AppleDeveloperAPI` only; the CLI source must not import the SDK.
- `architecture/protocol-default-pair` — depend on
  `any AppStoreConnectAPI`; `AppleDeveloperAPIDefault` stays internal.
- `architecture/namespaced-factory` — adds the long-promised
  `Factory.make(...)`.
- `concurrency/async-throws-contract` — CLI uses `async throws` flow end-to-end.
- `naming/single-error-type` — catches and reports `AppleDeveloperError`.
- `naming/any-existentials` — `any AppStoreConnectAPI` is the protocol
  type used everywhere in the CLI.
