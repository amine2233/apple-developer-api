---
name: Protocol + Default Implementation
description: Public Sendable protocol paired with an internal `*Default` struct; callers depend on the protocol, not the concrete type.
type: architecture
---

# Protocol + Default Implementation

Public capabilities are exposed as a `Sendable` protocol with the descriptive
name; the primary production implementation is an internal `struct` with a
`Default` suffix.

```swift
public protocol AppStoreConnectAPI: Sendable {
    func fetchBundleIds(bundleID: String) async throws
    func fetchProfile(id: String) async throws
    func fetchCertificate(id: String) async throws
}

struct AppleDeveloperAPIDefault: AppStoreConnectAPI { ... }
```

- Protocol is `public` and `Sendable`; impl is `internal` (no access modifier).
- Suffix is `Default` — never `Impl`, `Implementation`, `Concrete`.
- Test doubles may use `Mock`, `Fake`, `Stub` suffixes; only the primary impl uses `Default`.
- Callers depend on `any AppStoreConnectAPI`, never on the concrete type.
- Keeping the impl internal preserves freedom to rename / split / replace it without an API break.
