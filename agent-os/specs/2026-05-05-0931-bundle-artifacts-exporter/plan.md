# Plan — `BundleArtifactsExporter` Service

## Context

The wrapper today exposes a profile/cert *fetch* API but doesn't actually
materialize anything to disk. The real reason this project exists is to feed
build agents with `.mobileprovision` and `.cer` files for code-signing — so
we need a service that, given a bundle identifier, downloads its provisioning
profiles and their certificates from App Store Connect and writes them as
files in a known directory layout.

Two prior frictions inform the shape:

1. SDK 4.3.0 (latest, unmaintained since March 2024) is missing
   `case expired = "EXPIRED"` on `Profile.Attributes.ProfileState`. The user
   already worked around this in `fetchProfiles(forBundleIdentifier:)` by
   narrowing `fieldsProfiles` so the SDK never decodes `profileState`. The
   new exporter must use the same trick.

2. The slim `Profile`/`Certificate` domain models intentionally **exclude**
   the heavy base64 PEM payloads (`profileContent`, `certificateContent`).
   The exporter therefore reads these payloads directly from SDK types
   inside its impl rather than going through the existing wrapper methods.

Outcome: `BundleArtifactsExporter.exportArtifacts(forBundleIdentifier:to:)`
writes a deterministic tree of binary artifacts and returns a summary.

## Decisions locked with the user

- **Layering:** new public service inside the `AppleDeveloperAPI` library;
  separate from `AppStoreConnectAPI` (data fetching vs. file-system writes).
- **What to write:** `.mobileprovision` files for profiles, `.cer` files for
  certificates. **No** manifest JSON.
- **Layout:**
  `<output>/<bundle_id>/profiles/<uuid>.<ext>` where `<ext>` is
  `provisionprofile` when the profile's `platform` is macOS / Mac Catalyst
  (i.e. `BundleIDPlatform.macOs` or `.universal`) and `mobileprovision`
  otherwise (iOS, tvOS, anything else, or unknown).
  `<output>/<bundle_id>/certificates/<sanitized-displayName>.cer`
  (fall back to certificate id if displayName sanitizes to empty).
- **EXPIRED handling:** narrow `fields[profiles]` to
  `profileContent,uuid,name,platform,certificates` so `profileState` is
  never present in the response — captures EXPIRED profiles too. `platform`
  is included to drive the per-platform file extension. (`platform` is
  decoded from the SDK's `BundleIDPlatform` enum; if Apple ships a
  brand-new platform value the SDK can't recognize, decoding fails at the
  SDK layer the same way it does for `profileState=EXPIRED` — accepted risk.)
- **Single error type:** extend `AppleDeveloperError` with a new
  `.fileWriteFailure(path:underlying:)` case, no sibling Error type.
- **Smoke CLI:** wired in via an optional `--save-to <dir>` flag.

## Critical files

Existing — modify:
- `Sources/AppleDeveloperAPI/AppleDeveloperAPI.swift` — add
  `Factory.makeArtifactExporter(issuerID:privateKeyID:privateKey:)`.
- `Sources/AppleDeveloperAPI/AppleDeveloperError.swift` — add
  `.fileWriteFailure` case.
- `Sources/appstoreconnect-smoke/AppStoreConnectSmoke.swift` — add the
  `--save-to <dir>` flag and dispatch to the exporter when present.

New:
- `Sources/AppleDeveloperAPI/BundleArtifactsExporter.swift` — public Sendable
  protocol. **No** SDK import.
- `Sources/AppleDeveloperAPI/BundleArtifactsExporterDefault.swift` — internal
  `struct`, the only new file that
  `@preconcurrency import`s `AppStoreConnect_Swift_SDK`.
- `Sources/AppleDeveloperAPI/Models/ArtifactExportSummary.swift` —
  Sendable return value; no SDK import.
- `Tests/AppleDeveloperAPITests/BundleArtifactsExporterTests.swift` —
  fixture-driven tests for filename sanitization and the file-writer helper.

Reference (read-only):
- SDK paths under
  `~/Library/Developer/Xcode/DerivedData/.../checkouts/appstoreconnect-swift-sdk/Sources/OpenAPI/Generated/`:
  `Entities/Profile.swift` (attributes: `profileContent`, `uuid`, `name`,
  `relationships.certificates`), `Entities/Certificate.swift` (attributes:
  `certificateContent`, `displayName`, `name`),
  `Paths/PathsV1BundleIDs.swift` (`FieldsProfiles` enum),
  `Paths/PathsV1Certificates*WithID.swift` (`fieldsCertificates`).

## Tasks

### Task 1 — Save spec docs

Create `agent-os/specs/2026-05-05-HHMM-bundle-artifacts-exporter/`:
- `plan.md` — copy of this plan.
- `shape.md` — scope + decisions + context summary.
- `standards.md` — full text of the standards listed below.
- `references.md` — SDK file paths cited above.
- `visuals/` — empty (none provided).

### Task 2 — Extend `AppleDeveloperError`

In `Sources/AppleDeveloperAPI/AppleDeveloperError.swift`:

```swift
case fileWriteFailure(path: String, underlying: any Error)
```

### Task 3 — Add `ArtifactExportSummary`

`Sources/AppleDeveloperAPI/Models/ArtifactExportSummary.swift`:

```swift
public struct ArtifactExportSummary: Sendable, Hashable {
    public let bundleIdentifier: String
    public let profilesDirectory: URL
    public let certificatesDirectory: URL
    public let profileFiles: [URL]
    public let certificateFiles: [URL]
}
```

No SDK import.

### Task 4 — Add `BundleArtifactsExporter` protocol

`Sources/AppleDeveloperAPI/BundleArtifactsExporter.swift`:

```swift
public protocol BundleArtifactsExporter: Sendable {
    func exportArtifacts(
        forBundleIdentifier bundleIdentifier: String,
        to outputDirectory: URL
    ) async throws -> ArtifactExportSummary
}
```

No SDK import.

### Task 5 — Add `BundleArtifactsExporterDefault`

`Sources/AppleDeveloperAPI/BundleArtifactsExporterDefault.swift`:

```swift
@preconcurrency import AppStoreConnect_Swift_SDK
import Foundation

struct BundleArtifactsExporterDefault: BundleArtifactsExporter {
    private let provider: APIProvider
    init(provider: APIProvider) { self.provider = provider }

    func exportArtifacts(
        forBundleIdentifier bundleIdentifier: String,
        to outputDirectory: URL
    ) async throws -> ArtifactExportSummary {
        // 1. Resolve and create directories
        let bundleDir = outputDirectory
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
        let profilesDir = bundleDir
            .appendingPathComponent("profiles", isDirectory: true)
        let certificatesDir = bundleDir
            .appendingPathComponent("certificates", isDirectory: true)
        try Self.makeDirectory(profilesDir)
        try Self.makeDirectory(certificatesDir)

        // 2. Fetch profiles for bundle id, narrowed fields (skips profileState)
        let bundleReq = APIEndpoint.v1.bundleIDs.get(
            parameters: .init(
                filterIdentifier: [bundleIdentifier],
                fieldsProfiles: [.profileContent, .uuid, .name, .platform, .certificates],
                include: [.profiles]
            )
        )
        let bundleResp: AppStoreConnect_Swift_SDK.BundleIDsResponse
        do { bundleResp = try await provider.request(bundleReq) }
        catch { throw AppleDeveloperError.providerFailure(underlying: error) }

        // 3. Walk included[] for .profile cases; write each
        var profileFiles: [URL] = []
        var certIDs: Set<String> = []
        for item in bundleResp.included ?? [] {
            guard case let .profile(sdkProfile) = item else { continue }
            let url = try Self.writeProfile(
                sdkProfile,
                into: profilesDir
            )
            profileFiles.append(url)
            for d in sdkProfile.relationships?.certificates?.data ?? [] {
                certIDs.insert(d.id)
            }
        }

        // 4. Fetch each certificate (narrowed fields) and write
        var certificateFiles: [URL] = []
        for id in certIDs.sorted() {
            let url = try await Self.fetchAndWriteCertificate(
                id: id,
                provider: provider,
                into: certificatesDir
            )
            certificateFiles.append(url)
        }

        return ArtifactExportSummary(
            bundleIdentifier: bundleIdentifier,
            profilesDirectory: profilesDir,
            certificatesDirectory: certificatesDir,
            profileFiles: profileFiles,
            certificateFiles: certificateFiles
        )
    }
}
```

Helper outline (same file, internal `extension`):

- `static func makeDirectory(_ url: URL) throws` — wraps
  `FileManager.default.createDirectory(at:withIntermediateDirectories: true)`.
  Errors → `.fileWriteFailure`.

- `static func writeProfile(_ sdk: SDKProfile, into dir: URL) throws -> URL`
  - guard `attributes.profileContent`, `attributes.uuid` → else
    `.decodingFailure`.
  - `Data(base64Encoded:)` → else `.decodingFailure(field: "profileContent")`.
  - `let ext = profileExtension(for: attributes.platform)`.
  - target = `dir.appendingPathComponent("\(uuid).\(ext)")`.
  - `try data.write(to: target, options: .atomic)`; errors → `.fileWriteFailure`.

- `static func profileExtension(for platform: SDKBundleIDPlatform?) -> String`
  - `.macOs`, `.universal` → `"provisionprofile"` (macOS / Mac Catalyst).
  - everything else (`.ios`, `.services`, `nil`, future-unknown) → `"mobileprovision"`.

- `static func fetchAndWriteCertificate(id:provider:into:) async throws -> URL`
  - request = `APIEndpoint.v1.certificates.id(id).get(parameters: .init(fieldsCertificates: [.certificateContent, .displayName, .name]))`.
  - decode/validate `attributes.certificateContent`, `displayName`.
  - filename = `sanitize(displayName)`; if empty → use `id`.
  - target = `dir.appendingPathComponent("\(filename).cer")`.
  - write or `.fileWriteFailure`.

- `static func sanitize(_ name: String) -> String`
  - replace each `/`, `\\`, `:` with `_`; trim whitespace; collapse runs of `_`.
  - return result (may be empty).

`@preconcurrency import` is allowed here per `architecture/sdk-seam-isolation`
(this file actually uses SDK types).

### Task 6 — Add `Factory.makeArtifactExporter`

In `Sources/AppleDeveloperAPI/AppleDeveloperAPI.swift` `Factory`:

```swift
public static func makeArtifactExporter(
    issuerID: String,
    privateKeyID: String,
    privateKey: String
) throws -> any BundleArtifactsExporter {
    let cfg = try createConfiguration(
        issuerID: issuerID,
        privateKeyID: privateKeyID,
        privateKey: privateKey
    )
    return BundleArtifactsExporterDefault(
        provider: createProvider(usingConfiguration: cfg)
    )
}
```

### Task 7 — Tests

`Tests/AppleDeveloperAPITests/BundleArtifactsExporterTests.swift`:

- `@Suite("Filename sanitization")`
  - `sanitizesColonsAndSlashes()` — `"Apple Distribution: Acme/Corp"` →
    `"Apple Distribution_ Acme_Corp"`.
  - `collapsesRuns()` — `"a//:b"` → `"a_b"` (or whatever the rule produces;
    assert the deterministic output).
  - `emptyAfterStrip()` — input of all-disallowed chars → empty string;
    caller falls back to id (verified by writeCertificate test, see below).

- `@Suite("Profile writer")` (calls the file-write helper directly)
  - `writesValidBase64ContentAsMobileprovisionForIOS()` — pass
    `Data("hello".utf8).base64EncodedString()` + uuid `"ABC-123"` +
    `platform: .ios`; assert file at `<tmp>/ABC-123.mobileprovision`
    with content `"hello"`.
  - `writesProvisionprofileForMacOS()` — `platform: .macOs`; assert file
    at `<tmp>/<uuid>.provisionprofile`.
  - `writesProvisionprofileForUniversal()` — `platform: .universal`; assert
    `.provisionprofile`.
  - `defaultsToMobileprovisionWhenPlatformMissing()` — `platform: nil`;
    assert `.mobileprovision`.
  - `throwsOnMissingProfileContent()` — `attributes.profileContent = nil` →
    `AppleDeveloperError.decodingFailure(field: "profileContent", _)`.
  - `throwsOnInvalidBase64()` — `profileContent: "not base64!"` → throws
    `.decodingFailure(field: "profileContent", _)`.

The certificate fetch path is not unit-tested without a fake `APIProvider`
(out of scope); the sanitization + file-write paths cover the new logic.

### Task 8 — Wire into smoke CLI

In `Sources/appstoreconnect-smoke/AppStoreConnectSmoke.swift`:

- Add `let saveTo: String?` to `Config`.
- Parse `--save-to <dir>` in `Config.parse`.
- In `runPipeline(config:)`: if `saveTo != nil`, build the exporter via
  `AppleDeveloper.Factory.makeArtifactExporter(...)`, call
  `exportArtifacts(forBundleIdentifier: config.bundleIdentifier, to: URL(fileURLWithPath: saveTo))`,
  print a one-line summary (`"Wrote N profiles, M certificates to <dir>"`),
  return. Otherwise the existing print pipeline runs unchanged.
- Update `usageText` to document `--save-to`.

### Task 9 — Verify

```bash
xcrun swift build
xcrun swift test
swiftlint lint Sources Tests
```

Manual (with `.env.local` populated):

```bash
mise run smoke -- --save-to ./out
ls -R ./out/fr.intech-consulting.markpages
file ./out/fr.intech-consulting.markpages/profiles/*.mobileprovision
file ./out/fr.intech-consulting.markpages/certificates/*.cer
```

Expected: `*.mobileprovision` reports `data` or `PKCS7`, `*.cer` reports
`data` or `PKCS7` (the actual file types are binary signed payloads).

## Standards honored

- `architecture/sdk-seam-isolation` — only the `*Default` file imports the
  SDK; protocol + summary live in their own files without the import.
- `architecture/protocol-default-pair` — public Sendable protocol + internal
  `*Default` struct.
- `architecture/namespaced-factory` — assembly via
  `AppleDeveloper.Factory.makeArtifactExporter(...)`; no caller constructs
  `APIConfiguration` / `APIProvider` directly.
- `concurrency/async-throws-contract` — public method is `async throws`.
- `concurrency/sendable-protocols` — protocol + every signature type is Sendable.
- `concurrency/value-type-impls` — `*Default` is a `struct` with `private let provider`.
- `naming/single-error-type` — adds a case to `AppleDeveloperError`,
  no sibling Error type.
- `naming/any-existentials` — `any BundleArtifactsExporter` everywhere.

## Out of scope

- Recovering full `profileState` for EXPIRED profiles (would require SDK fork or PR).
- Manifest JSON / index files alongside the binary artifacts.
- Concurrent / parallel certificate fetches (sequential is fine for the typical 1–10 certs per bundle).
- Pagination beyond the SDK's default (limit 20 — sufficient for typical bundle profile counts).
- Caching / incremental writes — every run rewrites files (atomic per file).
- Cross-bundle exports in one call — caller invokes once per bundle id.
- Wiring an executor-cli task; the existing `mise run smoke -- --save-to <dir>` is enough.
