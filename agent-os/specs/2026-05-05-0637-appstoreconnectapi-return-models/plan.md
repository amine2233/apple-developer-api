# Plan — Domain-Modeled `AppStoreConnectAPI`

## Context

`Sources/AppleDeveloperAPI/AppleDeveloperAPI.swift:24-65` currently defines
`AppStoreConnectAPI` with three methods that return `Void` and just `print()`
the SDK response counts. The wrapper is meant to act as a repository over the
upstream `appstoreconnect-swift-sdk`; without return values it has no real use
to callers.

This change updates each method to return a Sendable domain model. Per
`agent-os/standards/architecture/sdk-seam-isolation.md`, no upstream SDK type
may appear in the public protocol's signatures, so the work introduces a
small, focused domain model layer plus a mapping seam. Method names are also
realigned with intent: today's `fetchBundleIds(bundleID:)` already passes
`include: [.profiles]` — its semantics are "fetch profiles for a bundle id",
not "fetch bundle ids".

After this change a caller can:
1. List provisioning profiles attached to a bundle identifier (e.g. `com.acme.app`).
2. Fetch a single profile by App Store Connect resource id, hydrated with its certificates.
3. Fetch a single certificate by App Store Connect resource id.

## Decisions locked with the user

- **Lean models.** Domain types contain only essential fields. The heavy
  base64 PEM payloads (`profileContent`, `certificateContent`) are **not**
  exposed in `Profile` / `Certificate`. If a content-bearing variant is needed
  later, add a dedicated type then — don't bloat the default model now.
- **Strict enum decoding.** Wrapper enums have **no** `.unknown` fallback.
  Unrecognized SDK raw values throw `AppleDeveloperError.decodingFailure`.
- **Scope.** No public `BundleIdentifier` model in this iteration. The bundle
  identifier is a `String` parameter to `fetchProfiles(forBundleIdentifier:)`
  and nothing more.
- **Rename for intent.**
  - `fetchBundleIds(bundleID:)` → `fetchProfiles(forBundleIdentifier:) -> [Profile]`
  - `fetchProfile(id:)` → `fetchProfileDetails(id:) -> ProfileDetails`
  - `fetchCertificate(id:)` keeps its name; gains `-> Certificate`.

## Critical files

Existing:
- `Sources/AppleDeveloperAPI/AppleDeveloperAPI.swift` — split + rewrite.
- `Tests/AppleDeveloperAPITests/AppleDeveloperAPITests.swift` — expand.
- `agent-os/standards/index.yml` — already lists the standards this plan honors.

New (proposed layout):
- `Sources/AppleDeveloperAPI/AppleDeveloperAPI.swift` — namespace + `Factory` only.
- `Sources/AppleDeveloperAPI/AppStoreConnectAPI.swift` — public protocol.
- `Sources/AppleDeveloperAPI/AppleDeveloperAPIDefault.swift` — internal impl.
- `Sources/AppleDeveloperAPI/AppleDeveloperError.swift` — single Error type.
- `Sources/AppleDeveloperAPI/Models/Profile.swift`
- `Sources/AppleDeveloperAPI/Models/Certificate.swift`
- `Sources/AppleDeveloperAPI/Models/ProfileDetails.swift`
- `Sources/AppleDeveloperAPI/Models/Enums.swift` — `Platform`, `ProfileType`, `ProfileState`, `CertificateType`.
- `Sources/AppleDeveloperAPI/Mapping/SDKMapping.swift` — only file (besides `*Default`) that imports the SDK.

Reference (read-only, for mapping):
- `~/Library/Developer/Xcode/DerivedData/apple-developer-api-cegjirocjnakncbknlnxjncmkexh/SourcePackages/checkouts/appstoreconnect-swift-sdk/Sources/OpenAPI/Generated/Entities/{BundleID,Profile,Certificate,BundleIDsResponse,ProfilesResponse,ProfileResponse,CertificateResponse}.swift`

## Tasks

### Task 1 — Save spec documentation

Create `agent-os/specs/2026-05-05-HHMM-appstoreconnectapi-return-models/`
(use the actual time at execution) containing:
- `plan.md` — copy of this plan.
- `shape.md` — scope, decisions, context (the four decisions above + open questions resolved).
- `standards.md` — full text of the standards that apply: `architecture/sdk-seam-isolation`, `architecture/protocol-default-pair`, `concurrency/async-throws-contract`, `concurrency/sendable-protocols`, `concurrency/value-type-impls`, `naming/single-error-type`, `naming/any-existentials`.
- `references.md` — pointers to the SDK entity files cited above.
- `visuals/` — empty directory (none provided).

### Task 2 — Add `AppleDeveloperError`

`Sources/AppleDeveloperAPI/AppleDeveloperError.swift`:

```swift
public enum AppleDeveloperError: Error, Sendable {
    case invalidConfiguration(reason: String)
    case providerFailure(underlying: any Error)
    case decodingFailure(field: String, reason: String)
    case missingRelationship(name: String, onResourceID: String)
    case unhydratedRelationship(name: String, missingIDs: [String])
    case resourceNotFound(kind: String, id: String)
}
```

No SDK import. `any Error` is Sendable in Swift 6.

### Task 3 — Add domain models

Lean fields only (no PEM content). All `public`, `Sendable`, `Hashable`, `Identifiable` where it makes sense.

`Models/Profile.swift`:

```swift
public struct Profile: Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let uuid: String
    public let platform: Platform
    public let profileType: ProfileType
    public let state: ProfileState
    public let expirationDate: Date
    public let bundleIdentifierID: String?
    public let certificateIDs: [String]
}
```

`Models/Certificate.swift`:

```swift
public struct Certificate: Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let displayName: String
    public let serialNumber: String
    public let certificateType: CertificateType
    public let platform: Platform?
    public let expirationDate: Date
}
```

`Models/ProfileDetails.swift`:

```swift
public struct ProfileDetails: Sendable, Identifiable, Hashable {
    public let profile: Profile
    public let certificates: [Certificate]
    public var id: String { profile.id }
}
```

`Models/Enums.swift` — wrapper enums with **no** `.unknown` fallback. Decoding logic in mapping layer throws `.decodingFailure(field:reason:)` on unrecognized raw values.

```swift
public enum Platform: String, Sendable, Hashable { case iOS, macOS, tvOS, universal }
public enum ProfileType: String, Sendable, Hashable {
    case iOSAppDevelopment, iOSAppStore, iOSAppAdHoc, iOSAppInHouse
    case macAppDevelopment, macAppStore, macAppDirect
    case tvOSAppDevelopment, tvOSAppStore, tvOSAppAdHoc, tvOSAppInHouse
}
public enum ProfileState: String, Sendable, Hashable { case active, invalid }
public enum CertificateType: String, Sendable, Hashable {
    case development, distribution, iOSDevelopment, iOSDistribution
    case macAppDistribution, macInstallerDistribution, macAppDevelopment
    case developerIDApplication, developerIDKext, passTypeID
}
```

(Final case lists must be re-checked against the SDK enums during implementation; this is the shape, not the contract.)

### Task 4 — Mapping layer

`Mapping/SDKMapping.swift` — internal, the only non-`*Default` file with `@preconcurrency import AppStoreConnect_Swift_SDK`.

- `extension Profile { init(sdk: AppStoreConnect_Swift_SDK.Profile) throws }`
  - Each missing-but-required attribute → `.decodingFailure(field:, reason: "missing")`.
  - `platform` / `profileType` / `state` raw-value decode → throw `.decodingFailure` on miss.
  - `bundleIdentifierID` ← `relationships.bundleID.data?.id` (optional).
  - `certificateIDs` ← `relationships.certificates.data?.map(\.id) ?? []`.
- `extension Certificate { init(sdk: AppStoreConnect_Swift_SDK.Certificate) throws }` — same pattern.
- `extension ProfileDetails { static func make(from response: AppStoreConnect_Swift_SDK.ProfileResponse) throws }`:
  1. `let profile = try Profile(sdk: response.data)`.
  2. Build `[String: SDK.Certificate]` lookup by pattern-matching `.certificate(let c)` in `response.included ?? []`.
  3. For each id in `profile.certificateIDs`, look up; collect missing → throw `.unhydratedRelationship(name: "certificates", missingIDs: …)`.
  4. Map each hit through `Certificate(sdk:)`.
- For `fetchProfiles(forBundleIdentifier:)`: extract `.profile(Profile)` cases out of `BundleIDsResponse.included ?? []` and map each through `Profile(sdk:)`. The current `fieldsProfiles: [.bundleID]` filter is wrong — drop it so the SDK returns full profile fields. Also drop `filterIdentifier` if the SDK supports the more direct `bundleIDs.id(_:).profiles.get(...)` path; otherwise keep `filterIdentifier: [bundleIdentifier]` and read profiles from `included`.

### Task 5 — Update protocol + Default impl

`AppStoreConnectAPI.swift`:

```swift
public protocol AppStoreConnectAPI: Sendable {
    func fetchProfiles(forBundleIdentifier bundleIdentifier: String) async throws -> [Profile]
    func fetchProfileDetails(id: String) async throws -> ProfileDetails
    func fetchCertificate(id: String) async throws -> Certificate
}
```

`AppleDeveloperAPIDefault.swift`:

- `struct AppleDeveloperAPIDefault: AppStoreConnectAPI` with `private let provider: APIProvider`.
- Each method:
  1. Build the matching `APIEndpoint.v1.…` request (correct `include:` for the profile-detail call: `[.certificates]`).
  2. `do { let response = try await provider.request(req) } catch { throw AppleDeveloperError.providerFailure(underlying: error) }`.
  3. Map via the `Mapping/` layer.
- Single-fetch endpoints throw `.resourceNotFound(kind: "profile"|"certificate", id:)` only if the SDK surfaces a 404 as something we can recognize; otherwise the SDK error becomes `.providerFailure`.

`AppleDeveloperAPI.swift` (now lean): just `enum AppleDeveloper { enum Factory { … } }`.

### Task 6 — Tests

`Tests/AppleDeveloperAPITests/`:

- Replace the empty `example()` with:
  - `mappingProfileSucceedsForValidSDKObject()` — feed a hand-built SDK `Profile` into `Profile(sdk:)`, `#expect` round-trip fields.
  - `mappingProfileThrowsOnUnknownProfileType()` — `#expect(throws: AppleDeveloperError.self)`.
  - `mappingProfileDetailsHydratesCertificatesFromIncluded()` — build a fake `ProfileResponse` with `.included = [.certificate(...)]`; `#expect(details.certificates.count == ids.count)`.
  - `mappingProfileDetailsThrowsWhenIncludedIsMissingACert()` — `.unhydratedRelationship` thrown.
  - `mappingCertificateSucceeds()` / `mappingCertificateThrowsOnUnknownType()`.
- No live network calls. The `*Default` impl is only exercised through mapping unit tests (it has no logic worth testing without an HTTP fake). If a fake `APIProvider` is reasonable to construct with the SDK's types, add one in-memory test that verifies the `.providerFailure` wrap.

Run with `swift test`. Single test: `swift test --filter AppleDeveloperAPITests.mappingProfileSucceedsForValidSDKObject`.

### Task 7 — Cleanup

- Delete the `print(...)` lines from the old impl.
- Remove the now-stale `example()` test if not already replaced.
- Run `swiftlint`; no new warnings.
- Confirm `swift build` and `swift test` are green under `swiftLanguageModes: [.v6]`.

## Standards honored (no changes to them)

- `architecture/sdk-seam-isolation` — only `*Default.swift` and `Mapping/SDKMapping.swift` carry `@preconcurrency import AppStoreConnect_Swift_SDK`.
- `architecture/protocol-default-pair` — public `AppStoreConnectAPI`, internal `AppleDeveloperAPIDefault`.
- `architecture/namespaced-factory` — `AppleDeveloper.Factory` unchanged.
- `concurrency/async-throws-contract` — every public method is `async throws`.
- `concurrency/sendable-protocols` — protocol is `Sendable`; every signature type is `Sendable`.
- `concurrency/value-type-impls` — impl is a `struct` with `private let provider`.
- `naming/single-error-type` — `AppleDeveloperError` is the module's only Error.
- `naming/any-existentials` — `case providerFailure(underlying: any Error)`.

## Verification

End-to-end:

```bash
mise install                 # pin toolchain (one-time per checkout)
swift build                  # must succeed, no new warnings under .v6
swift test                   # mapping tests green
swiftlint                    # no new violations
```

Manual smoke (optional, requires real App Store Connect creds):

```swift
let cfg = try AppleDeveloper.Factory.createConfiguration(
    issuerID: env.issuerID, privateKeyID: env.keyID, privateKey: env.privateKey)
let provider = AppleDeveloper.Factory.createProvider(usingConfiguration: cfg)
let api: any AppStoreConnectAPI = AppleDeveloperAPIDefault(provider: provider)

let profiles = try await api.fetchProfiles(forBundleIdentifier: "com.acme.demo")
let details  = try await api.fetchProfileDetails(id: profiles[0].id)
let cert     = try await api.fetchCertificate(id: details.certificates[0].id)
```

Acceptance:
- All three methods return non-`Void` Sendable domain values.
- Public protocol mentions zero `AppStoreConnect_Swift_SDK` types.
- Mapping unit tests cover happy path + every `AppleDeveloperError` case used.
- `swift build` + `swift test` + `swiftlint` all green.

## Out of scope (do not slip in)

- `BundleIdentifier` domain model and any `fetchBundleIdentifiers` method.
- Exposing `profileContent` / `certificateContent` PEM bytes.
- `.unknown` enum fallbacks.
- Pagination support, retry logic, cancellation policies.
- Any change to `Package.swift` dependencies, platforms, or language modes.
