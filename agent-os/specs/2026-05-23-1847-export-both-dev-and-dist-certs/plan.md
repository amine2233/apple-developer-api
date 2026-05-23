# Both Dev and Distribution Certificates Get Exported

## Context

The user has two certificates registered in their Apple Developer account for the same bundle ID — one Development and one Distribution — but when they run the artifact exporter, only one `.cer` file lands on disk. They suspected the distribution certificate was being overridden.

Reading `Sources/AppleDeveloperAPI/BundleArtifactsExporterDefault.swift` confirms the cause: the certificate file name is derived only from `certificate.displayName`. If two distinct certificates share the same sanitized display name, `Data.write(to:options:.atomic)` silently overwrites the first file with the second.

```swift
// BundleArtifactsExporterDefault.swift:84
static func writeCertificate(_ certificate: Certificate, into directory: URL) throws -> URL {
    let sanitized = sanitize(certificate.displayName)
    let basename = sanitized.isEmpty ? certificate.id : sanitized
    let target = directory.appendingPathComponent("\(basename).cer")
    ...
}
```

The dedup set `seenCertificateIDs` (line 26) uses `certificate.id`, so both certs are visited — but the filename collision swallows one of them on disk.

Intended outcome: every certificate written by the exporter lands at a unique path so dev/dist (and any other combination) coexist.

## Approach

Append the certificate's `id` to the filename so every written file is guaranteed unique, regardless of `displayName`. Keep the existing flat `certificates/` directory — no kind subfolders — per user preference.

Resulting filenames:

- Normal case: `Apple Development_ Acme - CERT1.cer`, `Apple Distribution_ Acme - CERT2.cer`.
- `displayName` sanitizes to empty: fall back to `CERT3.cer` (existing fallback, unchanged — the id is already there).

That is the entirety of the source-code change. The exporter's overall structure (loop, dedup, classification) is correct; only the writer is buggy.

## Files to modify

- `Sources/AppleDeveloperAPI/BundleArtifactsExporterDefault.swift`
  - In `writeCertificate(_:into:)` (line 84): build `basename` as `"\(sanitized) - \(certificate.id)"` when `sanitized` is non-empty; keep `certificate.id` alone as the fallback.

- `Tests/AppleDeveloperAPITests/BundleArtifactsExporterTests.swift`
  - Update `CertificateWriterTests.writesContentToSanitizedDisplayName` — expected filename is now `"Apple Distribution_ Acme_Corp - CID.cer"`.
  - `fallsBackToIDWhenDisplayNameSanitizesToEmpty` stays valid (empty-sanitization fallback unchanged).
  - Update `ExporterIntegrationFilterTests.keepsOnlyProfilesMatchingDistributionKind` — expected filename is now `"Dev Cert - CERT-DEV.cer"`.
  - Add a regression test: two certs with identical `displayName` but different ids and types (one `.iOSDevelopment`, one `.iOSDistribution`) attached to two profiles for the same bundle id → both files end up in `certificates/` with distinct names.

## Notable existing code to reuse — no changes needed

- `BundleArtifactsExporterDefault.sanitize(_:)` — keep as-is.
- `BundleArtifactsExporterDefault.classify(certs:)` — keep as-is.
- `seenCertificateIDs` dedup loop at line 44 — keep as-is.
- `MockAppStoreConnectAPI` in tests — keep as-is.

## Verification

- `swift build` — strict-concurrency build still passes (Swift 6 mode is on per `Package.swift`).
- `swift test` — full suite green, including the new regression test.
- `swift test --filter BundleArtifactsExporterTests` — focused run.
- Manual: with real ASC credentials in `.env.local`, run the exporter against a bundle id that has both a development and a distribution certificate; verify the output `certificates/` directory contains two `.cer` files (one per cert id).

## Out of scope

- No new public API on `AppStoreConnectAPI`; `fetchCertificate(id:)` is correct — it's a single-cert lookup, not the cause.
- No change to the `Certificate` model or to `SDKMapping`.
- No kind-based subfolder structure (explicitly declined in favor of the flat layout).
