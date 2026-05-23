# Standards for Export Both Dev and Distribution Certificates

The following standards apply to this work.

---

## architecture/protocol-default-pair

Public capabilities are exposed as a `Sendable` protocol with the descriptive name; the primary production implementation is an internal `struct` with a `Default` suffix.

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

**Why it applies here:** the fix is confined to `BundleArtifactsExporterDefault` — the public `BundleArtifactsExporter` protocol contract is unchanged.

---

## concurrency/strict-concurrency-mode

`Package.swift` is locked at `swiftLanguageModes: [.v6]`. Strict concurrency diagnostics get fixed at the source — never suppressed, never downgraded.

```swift
// Package.swift
swiftLanguageModes: [.v6]
```

- Do not lower to `.v5` or mixed mode. The mode is non-negotiable.
- Fix diagnostics by adding `Sendable`, actor isolation, or restructuring data.
- `@preconcurrency` is reserved for the upstream SDK import boundary (see `sdk-seam-isolation.md`). Never use it to silence first-party warnings.
- New dependencies must build cleanly under `.v6`, or be wrapped behind a `@preconcurrency` import at a single seam.

**Why it applies here:** the writer change is purely local string composition; no new mutable state, no concurrency implications.

---

## testing/swift-testing-only

All tests use the Swift Testing framework. No XCTest, no Quick, no Nimble.

```swift
import Testing
@testable import AppleDeveloperAPI

@Test
func fetchesBundleId() async throws {
    // ... use #expect / #require
}
```

- Imports: `import Testing` (+ `@testable import AppleDeveloperAPI` when needed).
- Use `@Test`, `@Suite`, `#expect`, `#require`. No `XCTAssert*`, no `setUp/tearDown`.
- No XCTest target — even for capabilities Swift Testing doesn't have yet. Wait or work around.
- No Quick / Nimble / third-party matcher DSLs.
- Run a single test by name: `swift test --filter AppleDeveloperAPITests.<testName>`.

**Why it applies here:** the new regression test must use `@Test`/`#expect`, matching the rest of `BundleArtifactsExporterTests.swift`.

---

## naming/single-error-type

The `AppleDeveloperAPI` module exposes exactly one error type: `public enum AppleDeveloperError: Error`. All throwing APIs in the module throw this type.

```swift
public enum AppleDeveloperError: Error, Sendable {
    case invalidConfiguration(reason: String)
    case providerFailure(underlying: Error)
    // ... add cases here as needs arise
}
```

- One Error type per module. No per-feature error enums (`BundleIDError`, `ProfileError`, etc.).
- Name: module name + `Error` suffix → `AppleDeveloperError`.
- `public` and `Sendable`.
- Wrap upstream / SDK errors in a case (e.g., `.providerFailure(underlying:)`) — never re-throw raw SDK error types.
- Add a new `case` rather than introducing a sibling Error type.

**Why it applies here:** the writer continues to throw `AppleDeveloperError.fileWriteFailure(path:underlying:)` on any I/O error; no new error type is introduced for this fix.
