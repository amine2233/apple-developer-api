# References for Route-Exporter-Through-API

## In this repo

- `Sources/AppleDeveloperAPI/AppStoreConnectAPI.swift` — public Sendable
  protocol with the three methods this work updates in semantics
  (return types gain content fields; 404 throws .resourceNotFound).
- `Sources/AppleDeveloperAPI/AppleDeveloperAPIDefault.swift` — the only
  intended SDK seam. This work moves all SDK calls (and base64 decoding
  via mapping) into here.
- `Sources/AppleDeveloperAPI/Mapping/SDKMapping.swift` — the second
  permitted SDK-importing file. Updated mapping inits decode `content`
  fields and use `Platform.init(sdk:field:)` (already present).
- `Sources/AppleDeveloperAPI/Models/Profile.swift` — replaced fields
  (id/uuid/name/platform/content).
- `Sources/AppleDeveloperAPI/Models/Certificate.swift` — adds
  `content: Data`.
- `Sources/AppleDeveloperAPI/Models/ProfileDetails.swift` — unchanged
  shape; just holds the richer types.
- `Sources/AppleDeveloperAPI/AppleDeveloperError.swift` —
  `.resourceNotFound(kind:id:)` reused for 404.
- `Sources/AppleDeveloperAPI/AppleDeveloperAPI.swift` — Factory
  `make(...)` already returns `any AppStoreConnectAPI`;
  `makeArtifactExporter(...)` rewires through it.
- `Sources/AppleDeveloperAPI/BundleArtifactsExporterDefault.swift` —
  the file this refactor targets. Drops `@preconcurrency import` and
  `APIProvider`; depends on `any AppStoreConnectAPI`.
- `Sources/appstoreconnect-smoke/AppStoreConnectSmoke.swift` — drops a
  print of `bundleIdentifierID` (field removed from Profile).
- `Tests/AppleDeveloperAPITests/AppleDeveloperAPITests.swift` —
  fixture helpers gain `profileContent`/`certificateContent` defaults.
- `Tests/AppleDeveloperAPITests/BundleArtifactsExporterTests.swift` —
  test fixtures move from SDK types to wrapper types
  (`Profile`/`Certificate`).

## Upstream SDK (read-only)

`~/Library/Developer/Xcode/DerivedData/apple-developer-api-cegjirocjnakncbknlnxjncmkexh/SourcePackages/checkouts/appstoreconnect-swift-sdk/Sources/`:

- `APIProvider.swift` — defines `APIProvider.Error.requestFailure(StatusCode, ErrorResponse?, URL?)`.
  This is what we pattern-match on `404` to translate to
  `AppleDeveloperError.resourceNotFound(...)`.
- `OpenAPI/Generated/Entities/Profile.swift` — `Attributes.profileContent`
  is the base64 PEM string we decode into `Profile.content`.
  `Attributes.uuid`, `name`, `platform: BundleIDPlatform?` are the other
  fields used.
- `OpenAPI/Generated/Entities/Certificate.swift` —
  `Attributes.certificateContent` is the base64 DER string we decode
  into `Certificate.content`.
- `OpenAPI/Generated/Paths/PathsV1BundleIDs.swift` — `FieldsProfiles`
  enum (`.profileContent, .uuid, .name, .platform`).
- `OpenAPI/Generated/Paths/PathsV1ProfilesWithID.swift` — narrow fields
  for `profiles.id(_:).get(parameters:)`.
- `OpenAPI/Generated/Paths/PathsV1CertificatesWithID.swift` — narrow
  fields for `certificates.id(_:).get(parameters:)`.
