# Domain-Modeled `AppStoreConnectAPI` — Shaping Notes

## Scope

Update `AppStoreConnectAPI` so each method returns a real Sendable domain
model. The wrapper acts as a repository over `appstoreconnect-swift-sdk`
with three operations:

1. List provisioning profiles attached to a bundle identifier string.
2. Fetch a single profile by App Store Connect resource id, hydrated with its certificates.
3. Fetch a single certificate by App Store Connect resource id.

Method renames driven by intent:

- `fetchBundleIds(bundleID:)` → `fetchProfiles(forBundleIdentifier:) -> [Profile]`
- `fetchProfile(id:)`         → `fetchProfileDetails(id:) -> ProfileDetails`
- `fetchCertificate(id:)`     → unchanged name; gains `-> Certificate`

## Decisions

- **Lean models.** `Profile` and `Certificate` carry only essential fields.
  PEM payloads (`profileContent`, `certificateContent`) are NOT exposed.
  Add a dedicated content-bearing type later if needed.
- **Strict enum decoding.** Wrapper enums have NO `.unknown` fallback.
  Unrecognized SDK raw values throw `AppleDeveloperError.decodingFailure`.
- **Bundle identifier scope.** No public `BundleIdentifier` model in this
  iteration — bundle identifier is just a `String` parameter.
- **Single Error type.** All throwing APIs throw `AppleDeveloperError`.
- **Strict required fields.** `name`, `uuid`, `expirationDate` etc. are
  non-optional in the domain model; mapping throws on missing.
- **`BundleIDPlatform` shape.** SDK exposes `ios`, `macOs`, `universal`,
  `services` (no tvOS — tvOS is reflected via `ProfileType`). Wrapper
  `Platform` mirrors this exactly.

## Context

- **Visuals:** None.
- **References:** Upstream SDK entities under
  `~/Library/Developer/Xcode/DerivedData/.../checkouts/appstoreconnect-swift-sdk/Sources/OpenAPI/Generated/Entities/`.
- **Product alignment:** `agent-os/product/` does not exist; no broader
  product context to align with.
- **Open questions resolved:**
  - Content encoding → drop content fields entirely (lean model).
  - Unknown enum values → throw `decodingFailure`.
  - `BundleIdentifier` model → out of scope for this iteration.
  - Method renames → approved.

## Standards Applied

- `architecture/sdk-seam-isolation` — only `*Default.swift` and `Mapping/SDKMapping.swift` import the SDK (with `@preconcurrency`).
- `architecture/protocol-default-pair` — public Sendable protocol + internal `*Default` struct.
- `architecture/namespaced-factory` — `AppleDeveloper.Factory` unchanged.
- `concurrency/async-throws-contract` — every public method is `async throws`.
- `concurrency/sendable-protocols` — protocol + every signature type is Sendable.
- `concurrency/value-type-impls` — Default impl is a `struct` with `private let provider`.
- `naming/single-error-type` — `AppleDeveloperError` is the module's only Error.
- `naming/any-existentials` — `case providerFailure(underlying: any Error)`.
