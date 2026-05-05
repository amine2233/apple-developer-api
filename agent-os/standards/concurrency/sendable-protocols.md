---
name: Sendable Protocol Surface
description: All public protocols inherit Sendable; every parameter, return, and thrown error in their signatures is Sendable.
type: concurrency
---

# Sendable Protocol Surface

All public protocols inherit `Sendable`. All types that appear in their
method signatures (parameters, returns, errors) are themselves `Sendable`.

```swift
public protocol AppStoreConnectAPI: Sendable {
    func fetchBundleIds(bundleID: String) async throws
    func fetchProfile(id: String) async throws
    func fetchCertificate(id: String) async throws
}
```

- Public protocol → `: Sendable`. Non-Sendable protocols stay internal.
- Every parameter / return / thrown error on a Sendable-protocol method is Sendable.
- DTOs default to `struct` with `Sendable` stored properties — automatic conformance.
- If a value isn't Sendable, fix it — don't mark the protocol or method as something else.
