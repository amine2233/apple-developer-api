# Plan — Route `BundleArtifactsExporter` Through `AppStoreConnectAPI`

## Context

`BundleArtifactsExporterDefault` violates the project's
`architecture/sdk-seam-isolation` standard: it `@preconcurrency import`s
`AppStoreConnect_Swift_SDK` and holds `APIProvider` directly, even though
the wrapper already has `AppleDeveloperAPIDefault` as the single intended
SDK seam. The exporter should depend on `any AppStoreConnectAPI`.

To do that without losing capability, the protocol's existing methods need
to grow to expose the bytes-bearing payloads the exporter relies on
(`profileContent`, `certificateContent`). The user has approved replacing
`fetchProfiles` (and aligning the rest) so we end up with one consistent
domain model that has the artifact bytes — no separate "Artifact" type.

A second concern from the live `mise run export` run: ASC sometimes
references profile ids in a bundle's `included[]` whose direct lookup
returns `404`. The exporter currently swallows that via an
`Optional`-returning internal helper. Per the user's approved decision,
the protocol will instead throw `AppleDeveloperError.resourceNotFound(kind:
"profile", id:)` and the exporter catches that one case to populate
`skippedProfileIDs`.

## Decisions locked with the user

- **Replace** `fetchProfiles(forBundleIdentifier:)` to return content-
  bearing profiles. The slim `Profile` (id, bundleIdentifierID,
  certificateIDs) is replaced with a richer `Profile` (id, uuid, name,
  platform, content). No separate `ProfileArtifact` type.
- **Replace** `Certificate` to add `content: Data`; keep the other fields.
- **Keep** `fetchProfileDetails(id:) -> ProfileDetails` and
  `fetchCertificate(id:) -> Certificate` — but they return the new richer
  models. `fetchProfileDetails` throws
  `AppleDeveloperError.resourceNotFound(kind: "profile", id: profileID)`
  on 404.
- **Refactor** `BundleArtifactsExporterDefault` to:
  - Hold `private let api: any AppStoreConnectAPI`. No SDK import.
  - Use `api.fetchProfiles(...)` then per-profile `api.fetchProfileDetails(...)`.
  - Catch `.resourceNotFound(kind: "profile", _)` only — populate
    `skippedProfileIDs` and continue.
- **Drop** `bundleIdentifierID` / `certificateIDs` from `Profile`. The
  smoke CLI's only reference to `bundleIdentifierID` (a print line in the
  default pipeline) is removed; that field is redundant — it's the same
  as the input bundle id.
- **No new public API** beyond the model field changes — protocol stays
  at three methods.

## Critical files

Existing — modify:
- `Sources/AppleDeveloperAPI/Models/Profile.swift` — replace fields
  (id, uuid, name, platform, content).
- `Sources/AppleDeveloperAPI/Models/Certificate.swift` — add `content: Data`.
- `Sources/AppleDeveloperAPI/Models/ProfileDetails.swift` — unchanged
  shape, but fields are richer types.
- `Sources/AppleDeveloperAPI/Mapping/SDKMapping.swift` — update
  `Profile.init(sdk:)` (decode content + uuid/name/platform), update
  `Certificate.init(sdk:)` (decode content), update
  `ProfileDetails.make(from:)` to iterate `included[]` directly without
  `certificateIDs` lookups.
- `Sources/AppleDeveloperAPI/AppleDeveloperAPIDefault.swift`
  - `fetchProfiles`: narrow fields to
    `[.profileContent, .uuid, .name, .platform]` + `include: [.profiles]`,
    walk `bundleResponse.included` for `.profile` cases, map to `Profile`.
  - `fetchProfileDetails`: narrow `fieldsProfiles` (no `profileState`) +
    narrow `fieldsCertificates`. Catch
    `APIProvider.Error.requestFailure(404, _, _)` and rethrow as
    `AppleDeveloperError.resourceNotFound(kind: "profile", id: profileID)`.
  - `fetchCertificate(id:)`: narrow `fieldsCertificates` to include
    `certificateContent`.
- `Sources/AppleDeveloperAPI/BundleArtifactsExporterDefault.swift`
  - Drop `@preconcurrency import AppStoreConnect_Swift_SDK`.
  - Replace `private let provider: APIProvider` with
    `private let api: any AppStoreConnectAPI`.
  - Pipeline:
    1. `let profiles = try await api.fetchProfiles(forBundleIdentifier:)`.
    2. For each profile, write its `content` to disk.
    3. For each profile id, `try await api.fetchProfileDetails(id:)`,
       write each `details.certificates[*].content` to disk; catch
       `.resourceNotFound(kind: "profile", _)` → append to
       `skippedProfileIDs`.
  - File-write helpers operate on wrapper types (`Profile`, `Certificate`)
    instead of SDK types. `sanitize` and `profileExtension(for:)` stay.
  - `profileExtension(for:)` now takes wrapper `Platform` (not
    `SDKBundleIDPlatform`).
- `Sources/AppleDeveloperAPI/AppleDeveloperAPI.swift` —
  `Factory.makeArtifactExporter(...)` builds `let api = try make(...)` and
  passes to `BundleArtifactsExporterDefault(api: api)`.
- `Sources/appstoreconnect-smoke/AppStoreConnectSmoke.swift` — remove the
  `print("    bundleId rel:   …")` line; other prints still work because
  Profile gains name/uuid/platform but they're not all printed (we just
  use `profile.id`).
- `Tests/AppleDeveloperAPITests/AppleDeveloperAPITests.swift` —
  - `makeSDKProfile` adds `profileContent` parameter (so happy-path tests
    can build a profile with bytes).
  - Profile mapping tests assert the new fields and the decoded content.
  - Certificate mapping tests assert the new `content` field.
  - ProfileDetails hydration tests update fixture content; assertions
    check certs have the decoded bytes.
- `Tests/AppleDeveloperAPITests/BundleArtifactsExporterTests.swift` —
  - Drop SDK fixture helpers. Replace with plain wrapper-type fixtures
    (`makeProfile(...)` returns `Profile`; `makeCertificate(...)` returns
    `Certificate`).
  - `writeProfile(_ Profile, into:)` and `writeCertificate(_ Certificate,
    into:)` test signatures (no SDK).
  - Sanitization + extension-selection tests stay; the latter calls
    `profileExtension(for: Platform)` with the wrapper enum.
  - The "throws on missing profileContent / certificateContent" tests are
    now covered at the mapping layer (`Profile.init(sdk:)` /
    `Certificate.init(sdk:)`); the exporter's writers no longer decode
    base64 — they just write `artifact.content` to disk.

No new files.

## Tasks

### Task 1 — Save spec docs

`agent-os/specs/2026-05-05-HHMM-route-exporter-through-api/`:
- `plan.md` — copy of this plan.
- `shape.md` — scope + decisions.
- `standards.md` — full text of relevant standards.
- `references.md` — pointers to BundleArtifactsExporterDefault.swift,
  AppStoreConnectAPI.swift, SDKMapping.swift, the SDK Profile/Certificate
  generated entities, and `APIProvider.Error` definition.
- `visuals/` — empty.

### Task 2 — Update domain models

`Profile.swift`:

```swift
public struct Profile: Sendable, Identifiable, Hashable {
    public let id: String
    public let uuid: String
    public let name: String
    public let platform: Platform
    public let content: Data
    public init(...) { ... }
}
```

`Certificate.swift`:

```swift
public struct Certificate: Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let displayName: String
    public let serialNumber: String
    public let certificateType: CertificateType
    public let platform: Platform?
    public let expirationDate: Date
    public let content: Data
    public init(...) { ... }
}
```

`ProfileDetails.swift` is unchanged (just holds the richer types now).

### Task 3 — Update mapping

`SDKMapping.swift`:

- `Profile.init(sdk:) throws`
  - Decode required attrs: `uuid`, `name`, `platform`, `profileContent`.
    Throw `.decodingFailure(field:, reason:)` if missing.
  - `Data(base64Encoded: profileContent)` → else
    `.decodingFailure(field: "profileContent", reason: "invalid base64")`.
  - Map `BundleIDPlatform → Platform` via existing `Platform.init(sdk:field:)`.
- `Certificate.init(sdk:) throws`
  - Existing fields plus decode `certificateContent` → `Data`. Same
    error contract.
- `ProfileDetails.make(from response:) throws`
  - `let profile = try Profile(sdk: response.data)`.
  - `let certificates = try (response.included ?? [])`
    `.compactMap { if case let .certificate(c) = $0 { c } else { nil } }`
    `.map { try Certificate(sdk: $0) }`.
  - No more `.unhydratedRelationship` / id-lookup logic — just take
    whatever `included[]` carries.
- Remove the `BundleIDsResponseMapping.extractProfiles(from:)` helper if
  it's no longer used after the Default impl is updated; otherwise keep.

### Task 4 — Update `AppleDeveloperAPIDefault`

`fetchProfiles(forBundleIdentifier:)`:

```swift
let req = APIEndpoint.v1.bundleIDs.get(parameters: .init(
    filterIdentifier: [bundleIdentifier],
    fieldsProfiles: [.profileContent, .uuid, .name, .platform],
    include: [.profiles]
))
let response = try await provider.request(req) // wrap → providerFailure
return try (response.included ?? []).compactMap {
    if case let .profile(p) = $0 { p } else { nil }
}.map { try Profile(sdk: $0) }
```

`fetchProfileDetails(id:)`:

```swift
let req = APIEndpoint.v1.profiles.id(id).get(parameters: .init(
    fieldsProfiles: [.profileContent, .uuid, .name, .platform],
    fieldsCertificates: [.certificateContent, .displayName, .name, .serialNumber, .certificateType, .platform, .expirationDate],
    include: [.certificates]
))
do {
    let response = try await provider.request(req)
    return try ProfileDetails.make(from: response)
} catch let error as APIProvider.Error {
    if case .requestFailure(404, _, _) = error {
        throw AppleDeveloperError.resourceNotFound(kind: "profile", id: id)
    }
    throw AppleDeveloperError.providerFailure(underlying: error)
}
```

`fetchCertificate(id:)`:

```swift
let req = APIEndpoint.v1.certificates.id(id).get(parameters: .init(
    fieldsCertificates: [.certificateContent, .displayName, .name, .serialNumber, .certificateType, .platform, .expirationDate]
))
// same 404 → resourceNotFound(kind: "certificate", id:) pattern, other → providerFailure
return try Certificate(sdk: response.data)
```

### Task 5 — Refactor `BundleArtifactsExporterDefault`

```swift
import Foundation

struct BundleArtifactsExporterDefault: BundleArtifactsExporter {
    private let api: any AppStoreConnectAPI

    init(api: any AppStoreConnectAPI) { self.api = api }

    func exportArtifacts(forBundleIdentifier bundleIdentifier: String, to outputDirectory: URL) async throws -> ArtifactExportSummary {
        // create dirs (unchanged)
        let profiles = try await api.fetchProfiles(forBundleIdentifier: bundleIdentifier)
        var profileFiles: [URL] = []
        for profile in profiles {
            profileFiles.append(try Self.writeProfile(profile, into: profilesDir))
        }

        var seen: Set<String> = []
        var certificateFiles: [URL] = []
        var skippedProfileIDs: [String] = []
        for profile in profiles {
            let details: ProfileDetails
            do {
                details = try await api.fetchProfileDetails(id: profile.id)
            } catch let AppleDeveloperError.resourceNotFound(kind, _) where kind == "profile" {
                skippedProfileIDs.append(profile.id)
                continue
            }
            for cert in details.certificates where seen.insert(cert.id).inserted {
                certificateFiles.append(try Self.writeCertificate(cert, into: certificatesDir))
            }
        }

        return ArtifactExportSummary(
            bundleIdentifier: bundleIdentifier,
            profilesDirectory: profilesDir,
            certificatesDirectory: certificatesDir,
            profileFiles: profileFiles,
            certificateFiles: certificateFiles,
            skippedProfileIDs: skippedProfileIDs
        )
    }

    static func writeProfile(_ profile: Profile, into dir: URL) throws -> URL {
        let target = dir.appendingPathComponent("\(profile.uuid).\(profileExtension(for: profile.platform))")
        do { try profile.content.write(to: target, options: .atomic) }
        catch { throw AppleDeveloperError.fileWriteFailure(path: target.path, underlying: error) }
        return target
    }

    static func writeCertificate(_ cert: Certificate, into dir: URL) throws -> URL {
        let sanitized = sanitize(cert.displayName)
        let target = dir.appendingPathComponent("\((sanitized.isEmpty ? cert.id : sanitized)).cer")
        do { try cert.content.write(to: target, options: .atomic) }
        catch { throw AppleDeveloperError.fileWriteFailure(path: target.path, underlying: error) }
        return target
    }

    static func profileExtension(for platform: Platform) -> String {
        switch platform {
        case .macOS, .universal: return "provisionprofile"
        default: return "mobileprovision"
        }
    }

    static func sanitize(_ name: String) -> String { /* unchanged */ }
    static func makeDirectory(_ url: URL) throws { /* unchanged */ }
}
```

No SDK import. No `APIProvider`. No base64 decoding (mapping layer handles it).

### Task 6 — Wire factory

`AppleDeveloperAPI.swift`:

```swift
public static func makeArtifactExporter(issuerID:..., privateKeyID:..., privateKey:...) throws -> any BundleArtifactsExporter {
    let api = try make(issuerID:..., privateKeyID:..., privateKey:...)
    return BundleArtifactsExporterDefault(api: api)
}
```

### Task 7 — Update smoke CLI

`AppStoreConnectSmoke.swift`: drop the
`print("    bundleId rel:   \(details.profile.bundleIdentifierID ?? "nil")")`
line. Other lines still work.

### Task 8 — Update tests

`AppleDeveloperAPITests.swift`:
- `makeSDKProfile`: gains a `profileContent` parameter (default to a
  small valid base64 like `Data("p".utf8).base64EncodedString()`).
- `makeSDKCertificate`: gains a `certificateContent` parameter (default
  to a small valid base64).
- Update `succeedsForValidSDKObject` for both to assert the new fields,
  including decoded `content`.
- Update `ProfileDetails hydration` tests: drop
  `unhydratedRelationship`-related test (no longer applicable — we don't
  cross-check IDs now). Keep `hydratesCertificatesFromIncluded` and
  `hydratesEmptyWhenNoCertRelationships`. Both with valid base64 content.

`BundleArtifactsExporterTests.swift`:
- Replace `makeProfileFixture` (SDK) and `makeCertificateFixture` (SDK)
  with plain `makeProfile(...)` returning `Profile` and
  `makeCertificate(...)` returning `Certificate`.
- `writeProfile` / `writeCertificate` tests now pass wrapper types and
  assert the bytes written. No "throws on missing fields" / "throws on
  invalid base64" tests in this suite — those move to mapping tests
  (already covered by `Profile.init(sdk:)` / `Certificate.init(sdk:)`).
- Sanitization + extension tests stay (keep the wrapper-Platform enum
  in extension tests).

### Task 9 — Verify

```bash
xcrun swift build
xcrun swift test
swiftlint lint Sources Tests
mise run export
```

Expected:
- All tests green.
- `mise run export` produces the same files under
  `./out/fr.intech-consulting.markpages/` and same skipped-IDs warning.
- `BundleArtifactsExporterDefault.swift` no longer contains
  `import AppStoreConnect_Swift_SDK`.

## Standards honored

- `architecture/sdk-seam-isolation` — only `AppleDeveloperAPIDefault.swift`
  and `Mapping/SDKMapping.swift` import the SDK after this work.
- `architecture/protocol-default-pair` — exporter depends on
  `any AppStoreConnectAPI`; impl stays internal.
- `architecture/namespaced-factory` — Factory adapts construction.
- `concurrency/async-throws-contract` — methods are `async throws`.
- `concurrency/sendable-protocols` — protocol + signature types are
  Sendable; new `content: Data` is Sendable.
- `naming/single-error-type` — adds zero new error cases; reuses
  `.resourceNotFound`.
- `naming/any-existentials` — `any AppStoreConnectAPI` everywhere.

## Out of scope

- Adding/changing `fetchCertificate(id:)` 404 behavior beyond the
  general `.resourceNotFound` pattern (consistency only).
- Pagination, parallel fetches, retries.
- Changing the on-disk layout produced by `mise run export`.
- Adding a manifest JSON.
- Touching `mise.toml` or `.env.local.example`.
