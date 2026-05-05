# References for `appstoreconnect-smoke` CLI

## Existing wrapper

- **`Sources/AppleDeveloperAPI/AppleDeveloperAPI.swift`** — `AppleDeveloper`
  namespace + `Factory` (currently exposes `createConfiguration` and
  `createProvider`). This is the file that grows the new public
  `Factory.make(...)` method.
- **`Sources/AppleDeveloperAPI/AppStoreConnectAPI.swift`** — public
  Sendable protocol the CLI calls. Three methods:
  - `fetchProfiles(forBundleIdentifier:) -> [Profile]`
  - `fetchProfileDetails(id:) -> ProfileDetails`
  - `fetchCertificate(id:) -> Certificate`
- **`Sources/AppleDeveloperAPI/AppleDeveloperAPIDefault.swift`** — internal
  conformance the new `Factory.make(...)` instantiates (and the CLI never
  references directly).
- **`Sources/AppleDeveloperAPI/AppleDeveloperError.swift`** — the single
  `AppleDeveloperError` enum the CLI catches and formats.
- **`Sources/AppleDeveloperAPI/Models/{Profile, Certificate, ProfileDetails,
  Enums}.swift`** — domain types the CLI prints.

## Upstream SDK auth (read-only reference)

- `~/Library/Developer/Xcode/DerivedData/.../checkouts/appstoreconnect-swift-sdk/`
  — the SDK whose `APIConfiguration(issuerID:privateKeyID:privateKey:)` is
  what the CLI ultimately feeds via `Factory.make(...)`. The CLI itself
  does **not** import this module.

## Existing executable patterns in the repo

- None. This is the first executable target in the package.

## Inline arg-parsing references

A small hand-rolled parser pattern (see Swift evolution discussions and
`swift run` tooling examples) is sufficient for this CLI's needs:
- `CommandLine.arguments` (drop arg 0 = binary path)
- Walk forward, treat any token starting with `--` as a flag with the
  next token as its value, otherwise treat as positional.
- Read `ProcessInfo.processInfo.environment` for env defaults.

No third-party arg-parser library is added (`swift-argument-parser`
explicitly declined to keep the dependency surface minimal — the
project's CLAUDE.md flags new third-party deps for explicit approval).
