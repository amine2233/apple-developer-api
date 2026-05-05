# AppleDeveloperAPI

A small Swift wrapper around [`AvdLee/appstoreconnect-swift-sdk`](https://github.com/AvdLee/appstoreconnect-swift-sdk)
that exposes a focused, `Sendable` API for fetching App Store Connect
provisioning profiles and certificates — and writing them to disk as
`.mobileprovision` / `.provisionprofile` / `.cer` files for code-signing
workflows (CI, build agents, fastlane replacements).

The library hides the upstream SDK behind a single seam, returns
`Sendable` domain types, and uses the project's single `AppleDeveloperError`
for all throwing paths.

## Requirements

- Swift 6.1 toolchain (Package.swift declares `swift-tools-version: 6.1`,
  `swiftLanguageModes: [.v6]`). CI pins **Swift 6.3.1**.
- iOS 14+ / macOS 11+ for library consumers.
- macOS 13+ to run the bundled `appstoreconnect-smoke` CLI.
- App Store Connect API credentials (issuer ID, key ID, `.p8` private key)
  for any code path that hits the live API.

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/amine2233/apple-developer-api.git", branch: "main")
```

then add `"AppleDeveloperAPI"` to the target's dependencies.

In Xcode: **File → Add Package Dependencies…** and paste the repo URL.

### Local development setup

This repo uses [mise](https://mise.jdx.dev) to pin Swift and the dev
tooling. Bootstrap a fresh checkout with:

```bash
mise install
```

That installs Swift 6.3.1 and `executor-cli` per `mise.toml`. After
that, `swift build` / `swift test` work as expected.

Optional `.env.local` for the bundled CLI:

```bash
cp .env.local.example .env.local
# edit .env.local: APP_STORE_CONNECT_ISSUER_ID, _KEY_ID, _PRIVATE_KEY_PATH
```

`.env.local` is gitignored. mise auto-loads it when entering the directory.

## Usage

### Construct the API

```swift
import AppleDeveloperAPI

let api = try AppleDeveloper.Factory.make(
    issuerID: "57246542-96fe-1a63-e053-0824d011072a",
    privateKeyID: "ABC1234567",
    privateKey: privateKeyBase64  // base64 body of AuthKey_<KEY_ID>.p8 (no PEM headers)
)
```

`Factory.make(...)` returns `any AppStoreConnectAPI`. The concrete type is
internal — depend on the protocol.

### Fetch profiles for a bundle identifier

```swift
let profiles = try await api.fetchProfiles(forBundleIdentifier: "com.acme.app")
for profile in profiles {
    print(profile.uuid, profile.name, profile.platform.rawValue)
    // profile.content holds the raw bytes of the .mobileprovision /
    // .provisionprofile (CMS-signed plist)
}
```

### Fetch a profile with its hydrated certificates

```swift
let details = try await api.fetchProfileDetails(id: profileID)
print(details.profile.name)
for cert in details.certificates {
    print(cert.displayName, cert.serialNumber)
    // cert.content holds the raw .cer bytes
}
```

The call throws `AppleDeveloperError.resourceNotFound(kind: "profile", id:)`
when the profile id no longer resolves on App Store Connect — common for
recently-expired profiles whose links remain in the bundle's relationships.

### Fetch a single certificate by id

```swift
let cert = try await api.fetchCertificate(id: certificateID)
```

### Export profiles + certificates to disk

```swift
let exporter = try AppleDeveloper.Factory.makeArtifactExporter(
    issuerID: ..., privateKeyID: ..., privateKey: ...
)

let summary = try await exporter.exportArtifacts(
    forBundleIdentifier: "com.acme.app",
    to: URL(fileURLWithPath: "./out", isDirectory: true)
)

print("Wrote \(summary.profileFiles.count) profiles, "
    + "\(summary.certificateFiles.count) certificates.")
print("Skipped (404): \(summary.skippedProfileIDs)")
```

Layout produced:

```
./out/com.acme.app/
  profiles/
    <uuid>.mobileprovision     ← iOS / tvOS profiles
    <uuid>.provisionprofile    ← macOS / Mac Catalyst profiles
  certificates/
    <displayName>.cer          ← falls back to the cert id when displayName sanitizes to empty
```

### Errors

All throwing APIs throw `AppleDeveloperError`:

| Case | Meaning |
| --- | --- |
| `.invalidConfiguration(reason:)` | Could not build `APIConfiguration` (bad credentials). |
| `.providerFailure(underlying:)` | Wrapper around an upstream SDK / transport failure. |
| `.decodingFailure(field:reason:)` | A required attribute was missing / unparseable on a response. |
| `.missingRelationship(name:onResourceID:)` | Reserved for future relationship-validation work. |
| `.unhydratedRelationship(name:missingIDs:)` | Reserved for future relationship-validation work. |
| `.resourceNotFound(kind:id:)` | 404 on a direct lookup. The exporter catches `kind == "profile"` and continues. |
| `.fileWriteFailure(path:underlying:)` | `FileManager` / `Data.write(to:)` failed. |

## Bundled CLI: `appstoreconnect-smoke`

Useful for verifying credentials end-to-end and for ad-hoc artifact
downloads. Two modes.

### Print pipeline (default)

```bash
swift run appstoreconnect-smoke com.acme.app
```

Sequentially calls `fetchProfiles → fetchProfileDetails → fetchCertificate`
on the first profile / first cert, printing each.

### Export to disk

```bash
swift run appstoreconnect-smoke com.acme.app --save-to ./out
```

Runs the full export pipeline (above) and prints a one-line summary.

### Flags

```
--issuer-id <id>            APP_STORE_CONNECT_ISSUER_ID
--key-id <id>               APP_STORE_CONNECT_KEY_ID
--private-key-path <path>   APP_STORE_CONNECT_PRIVATE_KEY_PATH (preferred)
--private-key <pem-or-b64>  APP_STORE_CONNECT_PRIVATE_KEY
--save-to <dir>             Switch to export pipeline; write files to <dir>
-h, --help                  Show help
```

The CLI accepts both PEM and raw-base64 forms for the private key —
PEM headers are stripped automatically.

### mise tasks

For convenience, `mise.toml` defines:

```bash
mise run smoke    # print pipeline against a hardcoded bundle id
mise run export   # export pipeline to ./out for a hardcoded bundle id
mise run test     # plain `swift test` (used by CI)
mise run format   # SwiftFormat via executor-cli
```

The `smoke` and `export` tasks have a bundle id hardcoded; edit
`[tasks.smoke]` / `[tasks.export]` in `mise.toml` for your own bundle, or
invoke the binary directly with a different positional argument.

## Continuous integration

`.github/workflows/ci.yml` runs `mise run test` (= `swift test`) on
`macos-latest` and `ubuntu-latest` for every pull request and every push
to `main`. mise provisions Swift and `executor-cli` from `mise.toml`;
the tools cache is keyed by mise.toml content and stored per-runner OS.

## Project layout

```
Sources/
  AppleDeveloperAPI/      Library target: protocol, internal Default impl, models, mapping
  appstoreconnect-smoke/  Executable target: print + export CLI
Tests/
  AppleDeveloperAPITests/ Swift Testing unit tests
agent-os/
  standards/              Engineering rules used in this codebase
  specs/                  Spec history for non-trivial changes
```

## Architecture & standards

The codebase follows the rules under `agent-os/standards/`. Headlines:

- **`architecture/sdk-seam-isolation`** — only `AppleDeveloperAPIDefault.swift`
  and `Mapping/SDKMapping.swift` import the upstream SDK. Domain code never
  sees SDK types.
- **`architecture/protocol-default-pair`** — public `Sendable` protocols
  paired with internal `*Default` structs. Callers depend on the protocol.
- **`architecture/namespaced-factory`** — `AppleDeveloper.Factory` is the
  only place that builds upstream `APIConfiguration` / `APIProvider`.
- **`concurrency/async-throws-contract`** — every public method is
  `async throws`; no callbacks, no Combine, no `Result`.
- **`concurrency/sendable-protocols`** — protocol + signature types are
  all `Sendable`.
- **`naming/single-error-type`** — one `AppleDeveloperError` enum for the
  whole module.

Read the individual files for full text.

## Credits

Built on top of [`AvdLee/appstoreconnect-swift-sdk`](https://github.com/AvdLee/appstoreconnect-swift-sdk).
