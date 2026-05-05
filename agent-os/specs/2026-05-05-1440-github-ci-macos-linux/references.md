# References for GitHub CI

## Actions used

- **`actions/checkout@v4`** — clones the repo into the runner workspace.
- **`swift-actions/setup-swift@v2`** — installs a specific Swift toolchain
  on the runner. Configured with `swift-version: '6.3.1'` to match
  `.swift-version`. Works on both macOS and Linux runners.
- **`jdx/mise-action@v2`** — installs mise and runs `mise install` based
  on `mise.toml`. After Swift is removed from `mise.toml`, it installs
  only `executor-cli`.

## In this repo

- `Package.swift` — Swift 6.0 toolchain, `swiftLanguageModes: [.v6]`,
  iOS 14 / macOS 11 minimums (Linux is implicit since SPM treats those
  platform constraints as Apple-only). Dependency tree
  (`appstoreconnect-swift-sdk`, `swift-asn1`, `swift-crypto`,
  `URLQueryEncoder`) is cross-platform.
- `mise.toml` — after this work, only pins `executor-cli` plus the
  `[env]` and `[tasks.*]` blocks.
- `.swift-version` — `6.3.1`. Canonical Swift pin (read by SPM and the
  CI workflow's setup-swift step).
- `Tests/AppleDeveloperAPITests/` — pure unit tests that don't hit
  the network or filesystem outside of
  `FileManager.default.temporaryDirectory`. Linux-safe.

## What CI does NOT do

- No swiftlint (per user choice).
- No `mise run smoke` / `mise run export` — those need ASC credentials
  (issuer ID, key ID, private key) that CI doesn't have.
- No coverage upload (codecov etc.).
- No SPM build caching (can be added later via `actions/cache` keyed on
  `Package.resolved`).
