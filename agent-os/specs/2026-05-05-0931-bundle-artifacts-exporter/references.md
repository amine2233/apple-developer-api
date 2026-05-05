# References for `BundleArtifactsExporter`

## In this repo

- `Sources/AppleDeveloperAPI/AppleDeveloperAPI.swift` — `AppleDeveloper` namespace +
  `Factory`. Gains a new `makeArtifactExporter(...)` method.
- `Sources/AppleDeveloperAPI/AppleDeveloperError.swift` — single Error enum;
  gains `.fileWriteFailure(path:underlying:)`.
- `Sources/AppleDeveloperAPI/AppStoreConnectAPI.swift` — sibling repository
  protocol. Exporter is intentionally separate.
- `Sources/AppleDeveloperAPI/AppleDeveloperAPIDefault.swift` — example of how
  the wrapper builds requests and wraps `provider.request` errors as
  `.providerFailure(underlying:)`. The exporter follows the same pattern.
- `Sources/appstoreconnect-smoke/AppStoreConnectSmoke.swift` — gains a
  `--save-to <dir>` flag that dispatches to the exporter.

## Upstream SDK (read-only)

Located under
`~/Library/Developer/Xcode/DerivedData/apple-developer-api-cegjirocjnakncbknlnxjncmkexh/SourcePackages/checkouts/appstoreconnect-swift-sdk/Sources/OpenAPI/Generated/`:

### Entities

- `Entities/Profile.swift` — `Attributes.profileContent` (base64 PEM),
  `uuid`, `name`, `platform: BundleIDPlatform?`,
  `Relationships.certificates.data: [Datum]?` (id-only refs).
- `Entities/Certificate.swift` — `Attributes.certificateContent` (base64
  DER), `displayName`, `name`.
- `Entities/BundleIDsResponse.swift` — `included: [IncludedItem]?` with
  `.profile(Profile)` cases used by the exporter.
- `Entities/CertificateResponse.swift` — single-cert fetch shape.
- `Entities/BundleIDPlatform.swift` — 4-case enum: `ios`, `macOs`,
  `universal`, `services`.

### Paths

- `Paths/PathsV1BundleIDs.swift` — `BundleIDs.GetParameters.FieldsProfiles`
  enum lists every narrow-able profile field, including `.profileContent`,
  `.uuid`, `.name`, `.platform`, `.certificates`. Listed values control
  `fields[profiles]=…`.
- `Paths/PathsV1CertificatesWithID.swift` (if present) /
  `Paths/PathsV1Certificates.swift` — `fieldsCertificates` controls
  `fields[certificates]=…` for the single-certificate fetch
  (`APIEndpoint.v1.certificates.id(_:).get(parameters:)`).

## EXPIRED workaround context

Spec `2026-05-05-0700-appstoreconnect-smoke-cli/` (sibling) documents the
prior smoke CLI work. The follow-on debugging revealed SDK 4.3.0 lacks
`case expired = "EXPIRED"` on `Profile.Attributes.ProfileState`, blocking
any response that includes an expired profile under default fields. The
exporter's narrow-fields query is the same workaround applied in
`AppleDeveloperAPIDefault.fetchProfiles(forBundleIdentifier:)`.
