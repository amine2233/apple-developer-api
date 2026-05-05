# Route Exporter Through `AppStoreConnectAPI` — Shaping Notes

## Scope

Refactor `BundleArtifactsExporterDefault` to depend on
`any AppStoreConnectAPI` rather than `APIProvider` directly. To keep the
exporter capable, the protocol's existing methods grow to expose
content-bearing payloads on `Profile` and `Certificate`. This restores
the project's `architecture/sdk-seam-isolation` standard (only
`AppleDeveloperAPIDefault.swift` and `Mapping/SDKMapping.swift` import
the SDK).

## Decisions

- Replace `fetchProfiles(forBundleIdentifier:)` to return content-bearing
  `Profile` (id, uuid, name, platform, content). Drop `bundleIdentifierID`
  / `certificateIDs` from `Profile`.
- Add `content: Data` to `Certificate`. Keep all other fields.
- `fetchProfileDetails(id:)` and `fetchCertificate(id:)` keep their
  signatures but operate on the new richer types.
- `fetchProfileDetails(id:)` throws
  `AppleDeveloperError.resourceNotFound(kind: "profile", id:)` on 404
  (the exporter catches this to populate `skippedProfileIDs`).
- Exporter holds `private let api: any AppStoreConnectAPI`; no SDK import.
- File-write helpers operate on `Profile`/`Certificate` wrapper types
  (no base64 decoding in the exporter — mapping layer handles it).
- Smoke CLI drops the `bundleIdentifierID` print (field no longer exists,
  redundant with the input bundle id).

## Context

- **Visuals:** None.
- **References:** existing wrapper sources, the SDK's APIProvider.Error
  definition for 404 detection.
- **Product alignment:** N/A.

## Standards Applied

- `architecture/sdk-seam-isolation` — only `AppleDeveloperAPIDefault.swift`
  and `Mapping/SDKMapping.swift` import the SDK after this work.
- `architecture/protocol-default-pair` — exporter depends on
  `any AppStoreConnectAPI`; impl stays internal.
- `architecture/namespaced-factory` — `Factory.makeArtifactExporter`
  builds the api via `make(...)`.
- `concurrency/async-throws-contract` — methods stay `async throws`.
- `concurrency/sendable-protocols` — protocol + signature types are
  Sendable; new `content: Data` is Sendable.
- `naming/single-error-type` — reuses `.resourceNotFound`; no new case.
- `naming/any-existentials` — `any AppStoreConnectAPI` everywhere.
