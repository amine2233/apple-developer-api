# `BundleArtifactsExporter` — Shaping Notes

## Scope

A new public service inside `AppleDeveloperAPI` that, given a bundle id and
an output directory, downloads provisioning profiles and certificates from
App Store Connect and writes them as files on disk:

- `<output>/<bundle_id>/profiles/<uuid>.<ext>` (`.mobileprovision` for
  iOS/tvOS/etc., `.provisionprofile` for macOS/Mac Catalyst).
- `<output>/<bundle_id>/certificates/<sanitized-displayName>.cer` (falls
  back to certificate id if displayName sanitizes to empty).

Returns an `ArtifactExportSummary` listing the resolved URLs.

## Decisions

- New protocol/Default pair separate from `AppStoreConnectAPI` so the
  repository fetching doesn't mix with file-system writes.
- No manifest JSON.
- `fields[profiles]=profileContent,uuid,name,platform,certificates` is the
  narrow-fields query — skips the SDK's `profileState` decoding (which
  rejects `EXPIRED` in v4.3.0) while keeping `platform` for the file
  extension.
- macOS extension rule: `BundleIDPlatform.macOs` or `.universal` →
  `.provisionprofile`, everything else → `.mobileprovision`.
- Single error type stays — adds `.fileWriteFailure(path:underlying:)` to
  `AppleDeveloperError`.
- Smoke CLI gains a `--save-to <dir>` flag that calls the exporter.
- Sequential certificate fetches (typical bundle has 1–10 certs).

## Context

- **Visuals:** None.
- **References:** existing wrapper (`Sources/AppleDeveloperAPI/`),
  upstream SDK at `~/Library/Developer/Xcode/DerivedData/.../checkouts/appstoreconnect-swift-sdk/Sources/OpenAPI/Generated/`.
- **Product alignment:** N/A (no `agent-os/product/`).

## Standards Applied

- `architecture/sdk-seam-isolation` — only `BundleArtifactsExporterDefault.swift`
  imports the SDK.
- `architecture/protocol-default-pair` — public Sendable protocol +
  internal `*Default`.
- `architecture/namespaced-factory` — assembly via
  `AppleDeveloper.Factory.makeArtifactExporter(...)`.
- `concurrency/async-throws-contract` — public method is `async throws`.
- `concurrency/sendable-protocols` — protocol + summary are Sendable.
- `concurrency/value-type-impls` — impl is a `struct` with `private let provider`.
- `naming/single-error-type` — adds a case to `AppleDeveloperError`.
- `naming/any-existentials` — `any BundleArtifactsExporter`.
