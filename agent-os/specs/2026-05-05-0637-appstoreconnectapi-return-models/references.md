# References for Domain-Modeled `AppStoreConnectAPI`

## Upstream SDK entities

The mapping layer reads these to translate SDK types → domain types.
Located under the Xcode DerivedData SourcePackages checkout:

`~/Library/Developer/Xcode/DerivedData/apple-developer-api-cegjirocjnakncbknlnxjncmkexh/SourcePackages/checkouts/appstoreconnect-swift-sdk/Sources/OpenAPI/Generated/Entities/`

### Resources

- **`Profile.swift`** — top-level model. Nested `Attributes` defines
  `ProfileType` (14 cases) and `ProfileState` (`active`, `invalid`).
  Relationships: `bundleID` (single), `devices` (array), `certificates` (array).
- **`Certificate.swift`** — top-level model. `Attributes` references the
  standalone `CertificateType`. Only relationship: `passTypeID` (single).
- **`BundleID.swift`** — top-level. Relationships: `profiles` (array),
  `bundleIDCapabilities` (array), `app` (single).

### Enums (raw-string Codable, CaseIterable)

- **`BundleIDPlatform.swift`** — `ios`, `macOs`, `universal`, `services`.
  This is what `Profile.attributes.platform` and `Certificate.attributes.platform` use.
- **`Platform.swift`** — separate enum (`ios`, `macOs`, `tvOs`, `visionOs`).
  Not used by Profile or Certificate; ignore for this iteration.
- **`CertificateType.swift`** — 18 cases including all Apple Pay variants,
  Developer ID Kext/Application (G2 variants), pass type IDs, etc.

### Response envelopes (JSON:API)

- **`BundleIDsResponse.swift`** — `data: [BundleID]`,
  `included: [IncludedItem]?` where `IncludedItem` is a discriminated union of
  `.app(App)`, `.bundleIDCapability(BundleIDCapability)`, `.profile(Profile)`.
- **`ProfilesResponse.swift`** — `data: [Profile]`, `included` is union of
  `.bundleID(BundleID)`, `.certificate(Certificate)`, `.device(Device)`.
- **`ProfileResponse.swift`** — single-profile fetch; same `included` union.
- **`CertificateResponse.swift`** — single-certificate fetch.

### JSON:API hydration pattern

When `include: [.certificates]` is passed to `/profiles/{id}`:
- `Profile.relationships.certificates.data` carries **IDs only**.
- Full `Certificate` objects appear in the response's `included` array as
  `.certificate(Certificate)` cases.
- The wrapper must build an `[id: SDK.Certificate]` lookup over the included
  array, then resolve each id from `relationships.certificates`.
- Missing IDs (referenced in relationships but absent from `included`) →
  `AppleDeveloperError.unhydratedRelationship(name: "certificates", missingIDs:)`.

## Existing wrapper file

- `Sources/AppleDeveloperAPI/AppleDeveloperAPI.swift` — pre-change source of
  the protocol + `*Default` impl. After this change it's split into the new
  layout described in `plan.md`.
