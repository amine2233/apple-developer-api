# References for Export Filters

## In this repo

- `Sources/AppleDeveloperAPI/BundleArtifactsExporter.swift` — protocol
  to extend.
- `Sources/AppleDeveloperAPI/BundleArtifactsExporterDefault.swift` —
  impl to refactor (filter pipeline + new `classify(certs:)` helper).
- `Sources/AppleDeveloperAPI/Models/Enums.swift` — `Platform` and
  `CertificateType` enums (filter target + classifier input).
- `Sources/AppleDeveloperAPI/Models/Profile.swift` — `platform` field
  drives the platform filter.
- `Sources/AppleDeveloperAPI/Models/Certificate.swift` —
  `certificateType` drives distribution-kind classification.
- `Sources/appstoreconnect-smoke/AppStoreConnectSmoke.swift` — unchanged;
  uses the 2-arg convenience overload.

## Upstream SDK (read-only)

The CertificateType cases mapped to distribution kinds:

| SDK case | Wrapper case | Distribution kind |
| --- | --- | --- |
| `DEVELOPMENT` | `.development` | development |
| `IOS_DEVELOPMENT` | `.iOSDevelopment` | development |
| `MAC_APP_DEVELOPMENT` | `.macAppDevelopment` | development |
| `DISTRIBUTION` | `.distribution` | distribution |
| `IOS_DISTRIBUTION` | `.iOSDistribution` | distribution |
| `MAC_APP_DISTRIBUTION` | `.macAppDistribution` | distribution |
| `MAC_INSTALLER_DISTRIBUTION` | `.macInstallerDistribution` | distribution |
| `DEVELOPER_ID_APPLICATION(_G2)` | `.developerIDApplication[G2]` | distribution |
| `DEVELOPER_ID_KEXT(_G2)` | `.developerIDKext[G2]` | distribution |
| `APPLE_PAY*`, `IDENTITY_ACCESS`, `PASS_TYPE_ID*` | various | (not classified — ignored by classifier) |

Reference: SDK
`OpenAPI/Generated/Entities/CertificateType.swift`.

## Why cert-type-based classification (not profileType)

`Profile.attributes.profileType` is a closed `String`-backed enum in
SDK 4.3.0 with 14 cases. Apple's API can return raw values the SDK
doesn't recognize (e.g. `VISIONOS_*` if a bundle has visionOS profiles).
The SDK's `decodeIfPresent(ProfileType.self, ...)` throws
`DecodingError.dataCorrupted` on unknown raw values, killing the entire
response. The wrapper currently sidesteps this by narrowing
`fields[profiles]` to skip `profileType` and `profileState`. Adding
`profileType` back would re-introduce the trap. Cert types are decoded
from a more stable `CertificateType` enum (18 cases including Apple Pay
variants) and are sufficient to classify a profile's intended use.
