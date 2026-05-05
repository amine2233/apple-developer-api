---
name: async throws Contract
description: Every public wrapper method is async throws; no callbacks, no Combine, no Result variants.
type: concurrency
---

# async throws Contract

Every public wrapper method is `async throws`. No callbacks, no Combine,
no `Result`-returning variants.

```swift
public protocol AppStoreConnectAPI: Sendable {
    func fetchBundleIds(bundleID: String) async throws
    func fetchProfile(id: String) async throws
    func fetchCertificate(id: String) async throws
}
```

- Anything touching the SDK is `async throws` — no exceptions.
- Pure helpers (formatters, transforms with no I/O / no failure path) may be sync non-throwing.
- No Combine publishers, no completion-handler callbacks on the public API.
- Errors propagate via `throws`; do not return `Result<…, Error>`.
