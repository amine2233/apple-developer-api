# References for Export Both Dev and Distribution Certificates

## Bug site

### `writeCertificate(_:into:)`

- **Location:** `Sources/AppleDeveloperAPI/BundleArtifactsExporterDefault.swift:84`
- **Relevance:** The single function responsible for turning a `Certificate` into a file on disk. Its basename calculation considers only `displayName`, so two certs whose sanitized display names collide overwrite each other.
- **Key patterns:**
  - Sanitization via `BundleArtifactsExporterDefault.sanitize(_:)`.
  - Fallback to `certificate.id` when sanitization yields the empty string.
  - Atomic write through `Data.write(to:options:.atomic)`, which silently replaces existing files.

## Surrounding flow

### `exportArtifacts(forBundleIdentifier:to:platforms:distributionKinds:)`

- **Location:** `Sources/AppleDeveloperAPI/BundleArtifactsExporterDefault.swift:10`
- **Relevance:** Confirms both certificates are actually visited even with the bug. The per-cert loop dedups on `certificate.id` (not on filename), so the issue is strictly at the write step.
- **Key patterns:**
  - `seenCertificateIDs: Set<String>` keyed by id — correct, do not change.
  - `Self.classify(certs:)` used only to decide whether to keep a profile, not to drive filenames.

## Existing tests to update

### `CertificateWriterTests`

- **Location:** `Tests/AppleDeveloperAPITests/BundleArtifactsExporterTests.swift:129`
- **Relevance:** Pins the current (buggy) filename behavior. The first test's expected name must change from `"Apple Distribution_ Acme_Corp.cer"` to `"Apple Distribution_ Acme_Corp - CID.cer"`. The empty-sanitization fallback test stays valid.
- **Key patterns:** Uses `makeTempDir`, `makeCertificate(...)`, and direct calls to `BundleArtifactsExporterDefault.writeCertificate(_:into:)`.

### `ExporterIntegrationFilterTests.keepsOnlyProfilesMatchingDistributionKind`

- **Location:** `Tests/AppleDeveloperAPITests/BundleArtifactsExporterTests.swift:247`
- **Relevance:** Asserts exact filenames via `summary.certificateFiles.map(\.lastPathComponent)`. Expected list updates from `["Dev Cert.cer"]` to `["Dev Cert - CERT-DEV.cer"]`.

## Test support to reuse

### `MockAppStoreConnectAPI`

- **Location:** `Tests/AppleDeveloperAPITests/MockAppStoreConnectAPI.swift`
- **Relevance:** The regression test composes profiles, details, and certificates through this mock without touching the network. Use the existing initializer surface.
