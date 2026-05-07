# Plan — Filter Exports by Platform + Distribution Kind

## Context

`BundleArtifactsExporter.exportArtifacts(...)` currently exports every
profile and every attached certificate for a bundle id. Real workflows
need a narrower slice — e.g. "just the iOS development profile + cert
for running tests on a sim", or "just the iOS distribution profile + cert
for archive". Two new filter parameters let callers express this:

- **`platforms: Set<Platform>`** — keep only profiles whose `platform`
  is in the set. Defaults to `[.iOS, .macOS]`.
- **`distributionKinds: Set<DistributionKind>`** — keep only profiles
  whose distribution kind is in the set. Defaults to
  `[.development, .distribution]`.

Distribution kind is **derived from the certificates attached to a
profile**, not from `profileType`. The slim `Profile` model deliberately
omits `profileType` so the pipeline isn't vulnerable to Apple adding
new profile types (visionOS, etc.) that SDK 4.3.0's enum can't decode.
Every cert we already fetch has a stable `CertificateType` we can map
into a distribution kind; that's enough.

The flat on-disk layout is unchanged.

## Decisions locked with the user

- **Detection**: `Certificate.certificateType` → `DistributionKind`
  classifier. Robust against ASC adding new `ProfileType` values.
- **Platform filter shape**: `Set<Platform>` (literal). `.universal`
  (Mac Catalyst) is included only if the caller adds `.universal` to
  the set explicitly.
- **Defaults**: `platforms = [.iOS, .macOS]`,
  `distributionKinds = [.development, .distribution]`. Provided via a
  convenience overload on the protocol so existing 2-arg callers keep
  compiling.
- **Layout**: stays flat
  (`<out>/<bundle>/profiles/...` + `<out>/<bundle>/certificates/...`).
- **Smoke CLI**: untouched in this iteration. The 2-arg
  convenience overload covers the default. Adding `--platforms` /
  `--kinds` flags can be a follow-up.

## Critical files

Existing — modify:
- `Sources/AppleDeveloperAPI/BundleArtifactsExporter.swift` — protocol
  gains the 4-arg method; default-impl extension adds the 2-arg overload.
- `Sources/AppleDeveloperAPI/BundleArtifactsExporterDefault.swift` —
  reorders the pipeline to apply both filters before writing; classifies
  each profile by its certs.
- `Tests/AppleDeveloperAPITests/BundleArtifactsExporterTests.swift` —
  new tests for the classifier + an integration test using a fake API.

New:
- `Sources/AppleDeveloperAPI/Models/DistributionKind.swift` — public
  Sendable enum with cases `.development`, `.distribution`.
- `Tests/AppleDeveloperAPITests/MockAppStoreConnectAPI.swift` — small
  test-only fake of `AppStoreConnectAPI` for end-to-end filter tests.

Reference (read-only):
- `Sources/AppleDeveloperAPI/Models/Enums.swift` — existing
  `Platform` and `CertificateType` enums (filter targets + classifier
  inputs).
- `Sources/AppleDeveloperAPI/Models/Profile.swift` — `platform` field
  used for the platform filter.

## Tasks

### Task 1 — Save spec docs

`agent-os/specs/2026-05-05-HHMM-export-filters-platform-distribution/`:
- `plan.md` — copy of this plan.
- `shape.md` — scope + decisions.
- `standards.md` — relevant standards.
- `references.md` — file pointers.
- `visuals/` — empty.

### Task 2 — Add `DistributionKind` model

`Models/DistributionKind.swift`:

```swift
public enum DistributionKind: String, Sendable, Hashable, CaseIterable {
    case development
    case distribution
}
```

No SDK import.

### Task 3 — Extend `BundleArtifactsExporter` protocol + convenience overload

`BundleArtifactsExporter.swift`:

```swift
public protocol BundleArtifactsExporter: Sendable {
    func exportArtifacts(
        forBundleIdentifier bundleIdentifier: String,
        to outputDirectory: URL,
        platforms: Set<Platform>,
        distributionKinds: Set<DistributionKind>
    ) async throws -> ArtifactExportSummary
}

public extension BundleArtifactsExporter {
    /// Convenience overload using the default filters
    /// (`platforms: [.iOS, .macOS]`, `distributionKinds: [.development, .distribution]`).
    func exportArtifacts(
        forBundleIdentifier bundleIdentifier: String,
        to outputDirectory: URL
    ) async throws -> ArtifactExportSummary {
        try await exportArtifacts(
            forBundleIdentifier: bundleIdentifier,
            to: outputDirectory,
            platforms: [.iOS, .macOS],
            distributionKinds: [.development, .distribution]
        )
    }
}
```

Existing call site (`AppStoreConnectSmoke.runExportPipeline`) hits the
2-arg overload — no change needed.

### Task 4 — Refactor `BundleArtifactsExporterDefault.exportArtifacts`

The new pipeline:

```swift
func exportArtifacts(
    forBundleIdentifier bundleIdentifier: String,
    to outputDirectory: URL,
    platforms: Set<Platform>,
    distributionKinds: Set<DistributionKind>
) async throws -> ArtifactExportSummary {
    // 1. Resolve dirs + create.
    // 2. Fetch profile list.
    let profiles = try await api.fetchProfiles(forBundleIdentifier: bundleIdentifier)

    var profileFiles: [URL] = []
    var certificateFiles: [URL] = []
    var seenCertIDs: Set<String> = []
    var skippedProfileIDs: [String] = []

    for profile in profiles {
        // 3. Apply platform filter early — no per-profile fetch needed for excluded platforms.
        guard platforms.contains(profile.platform) else { continue }

        // 4. Per-profile fetch (still needed for certs + classification).
        let details: ProfileDetails
        do {
            details = try await api.fetchProfileDetails(id: profile.id)
        } catch let AppleDeveloperError.resourceNotFound(kind, _) where kind == "profile" {
            skippedProfileIDs.append(profile.id)
            continue
        }

        // 5. Classify; apply distribution-kind filter.
        let kinds = Self.classify(certs: details.certificates)
        guard !kinds.isDisjoint(with: distributionKinds) else { continue }

        // 6. Write profile + (deduplicated) certs.
        profileFiles.append(try Self.writeProfile(profile, into: profilesDir))
        for cert in details.certificates where seenCertIDs.insert(cert.id).inserted {
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
```

New helper (same file):

```swift
static func classify(certs: [Certificate]) -> Set<DistributionKind> {
    var kinds: Set<DistributionKind> = []
    for cert in certs {
        switch cert.certificateType {
        case .development, .iOSDevelopment, .macAppDevelopment:
            kinds.insert(.development)
        case .distribution, .iOSDistribution,
             .macAppDistribution, .macInstallerDistribution,
             .developerIDApplication, .developerIDApplicationG2,
             .developerIDKext, .developerIDKextG2:
            kinds.insert(.distribution)
        case .applePay, .applePayMerchantIdentity, .applePayPspIdentity, .applePayRSA,
             .identityAccess, .passTypeID, .passTypeIDWithNFC:
            continue
        }
    }
    if kinds.isEmpty { kinds.insert(.distribution) } // safe default
    return kinds
}
```

Notes:
- The `Set<DistributionKind>` return value handles mixed-cert profiles
  (rare but real): a profile that's matched by either filter passes
  through.
- We call `fetchProfileDetails` even for profiles that fail the
  distribution-kind filter — there's no way to know the kind without
  the certs. Platform-filtered profiles short-circuit before this call.

### Task 5 — Add `MockAppStoreConnectAPI` test fixture

`Tests/AppleDeveloperAPITests/MockAppStoreConnectAPI.swift`:

```swift
struct MockAppStoreConnectAPI: AppStoreConnectAPI {
    var profiles: [Profile] = []
    var detailsByID: [String: ProfileDetails] = [:]
    var notFoundProfileIDs: Set<String> = []
    var certificatesByID: [String: Certificate] = [:]

    func fetchProfiles(forBundleIdentifier _: String) async throws -> [Profile] { profiles }

    func fetchProfileDetails(id: String) async throws -> ProfileDetails {
        if notFoundProfileIDs.contains(id) {
            throw AppleDeveloperError.resourceNotFound(kind: "profile", id: id)
        }
        guard let details = detailsByID[id] else {
            throw AppleDeveloperError.resourceNotFound(kind: "profile", id: id)
        }
        return details
    }

    func fetchCertificate(id: String) async throws -> Certificate {
        guard let cert = certificatesByID[id] else {
            throw AppleDeveloperError.resourceNotFound(kind: "certificate", id: id)
        }
        return cert
    }
}
```

### Task 6 — Tests

Add a new suite to `BundleArtifactsExporterTests.swift`:

`@Suite("Distribution-kind classifier")`
- `developmentCertReturnsDevelopment` — `[iOSDevelopment]` → `[.development]`.
- `distributionCertReturnsDistribution` — `[iOSDistribution]` → `[.distribution]`.
- `mixedReturnsBoth` — `[iOSDevelopment, iOSDistribution]` → `[.development, .distribution]`.
- `developerIDIsDistribution` — `[developerIDApplication]` → `[.distribution]`.
- `applePayIsIgnored` — `[applePay]` → `[.distribution]` (ignored cert types
  fall through to safe default).
- `noCertsDefaultsToDistribution` — `[]` → `[.distribution]`.

`@Suite("Exporter integration filters")` — uses `MockAppStoreConnectAPI`,
real `BundleArtifactsExporterDefault`, real disk writes (temp dir):
- `keepsOnlyProfilesMatchingPlatformFilter` — 1 iOS + 1 macOS profile;
  `platforms: [.iOS]` → only iOS profile written. Cert from macOS
  profile is NOT written.
- `keepsOnlyProfilesMatchingDistributionKind` — 1 dev + 1 distribution
  profile; `distributionKinds: [.development]` → only the dev profile
  + its cert.
- `combinedFiltersIntersect` — many profiles; only the iOS dev one
  survives both filters.
- `convenienceOverloadIncludesEverything` — calls the 2-arg overload;
  every profile + cert gets written.
- `skippedProfileIDsStillReportedWhenFiltered` — a profile passes
  platform filter but `fetchProfileDetails` throws `.resourceNotFound`;
  the id appears in `summary.skippedProfileIDs` regardless.

### Task 7 — Verify

```bash
xcrun swift build
xcrun swift test                       # all suites pass
swiftlint lint Sources Tests           # 0 violations
mise run export                        # still produces files for the user's bundle
```

## Standards honored

- `architecture/sdk-seam-isolation` — exporter still imports zero SDK
  symbols. New `DistributionKind` is SDK-free.
- `architecture/protocol-default-pair` — protocol stays public Sendable;
  default impl stays internal.
- `concurrency/async-throws-contract` — both new and old methods are
  `async throws`.
- `concurrency/sendable-protocols` — `DistributionKind` is `Sendable`,
  `Hashable`. `Set<Platform>` and `Set<DistributionKind>` are Sendable.
- `naming/single-error-type` — no new error cases; reuses the existing
  `.resourceNotFound` semantics.
- `naming/any-existentials` — existing usage preserved.

## Out of scope

- Adding `--platforms` / `--kinds` CLI flags to `appstoreconnect-smoke`
  (default convenience overload already covers it; can add later).
- Detecting distribution kind from `profileType` (re-introducing SDK
  enum risk).
- `.universal` auto-inclusion when `.iOS` or `.macOS` is requested.
- Per-cert classification (filter only acts at the profile level).
- A separate "filter summary" field in `ArtifactExportSummary`. Callers
  can compare counts to the original profile list themselves.

## Verification

Acceptance:
- `swift build` and `swift test` clean (existing 25 + ~11 new tests).
- `swiftlint Sources Tests` clean.
- Existing `mise run export` still produces 11 profile files / 1 cert
  for the user's bundle (defaults: both platforms, both kinds).
- `BundleArtifactsExporterDefault.swift` still has zero SDK imports.
- `Sources/AppleDeveloperAPI/Models/DistributionKind.swift` exists,
  is `public Sendable Hashable CaseIterable`, has cases `.development`
  and `.distribution`.
- `Tests/AppleDeveloperAPITests/MockAppStoreConnectAPI.swift` exists
  and conforms to `AppStoreConnectAPI`.
