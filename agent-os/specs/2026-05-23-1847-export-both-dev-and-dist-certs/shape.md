# Export Both Dev and Distribution Certificates — Shaping Notes

## Scope

Fix `BundleArtifactsExporter` so that when a bundle id has both a Development and a Distribution certificate, both certificate files end up on disk. Currently only one is written; the second silently overwrites the first because the filename is derived only from `displayName`.

## Decisions

- **Root cause is in the writer, not the API.** `AppStoreConnectAPI.fetchCertificate(id:)` is a single-cert lookup and is correct as-is. The dedup keyed by `certificate.id` in `exportArtifacts` is also correct. The bug lives entirely in `BundleArtifactsExporterDefault.writeCertificate`.
- **Filename strategy: append `certificate.id` to the sanitized display name.** Chosen for guaranteed uniqueness with minimal structural change.
- **Flat `certificates/` directory kept.** Subfolders per kind (`development/`, `distribution/`) were considered and explicitly declined in favor of the flatter layout.
- **No new public API surface.** Nothing added to `AppStoreConnectAPI` or `BundleArtifactsExporter`.
- **Existing tests updated, plus one new regression test** covering the same-`displayName` case that the previous behavior masked.

## Context

- **Visuals:** None.
- **References:**
  - `Sources/AppleDeveloperAPI/BundleArtifactsExporterDefault.swift:84` — the buggy `writeCertificate(_:into:)`.
  - `Sources/AppleDeveloperAPI/BundleArtifactsExporterDefault.swift:44` — the per-profile cert loop with `seenCertificateIDs` dedup (proves both certs are visited).
  - `Tests/AppleDeveloperAPITests/BundleArtifactsExporterTests.swift` — existing `CertificateWriterTests` and `ExporterIntegrationFilterTests` suites needed expectation updates.
- **Product alignment:** N/A (no `agent-os/product/` directory).

## Standards Applied

- `architecture/protocol-default-pair` — change stays internal to `BundleArtifactsExporterDefault`; the public `BundleArtifactsExporter` protocol is untouched.
- `concurrency/strict-concurrency-mode` — fix must still compile under `swiftLanguageModes: [.v6]`; the new code introduces no shared mutable state.
- `testing/swift-testing-only` — regression test uses `@Test` / `#expect`, matching the rest of the suite.
- `naming/single-error-type` — file-write failures continue to throw `AppleDeveloperError.fileWriteFailure`; no new error type introduced.
