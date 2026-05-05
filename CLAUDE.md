# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Swift package that wraps [`AvdLee/appstoreconnect-swift-sdk`](https://github.com/AvdLee/appstoreconnect-swift-sdk) to expose a higher-level Apple Developer / App Store Connect API surface. Single library product: `AppleDeveloperAPI`.

## Toolchain

- Swift 6.1 toolchain, `swiftLanguageModes: [.v6]` — strict concurrency is on. The SDK dependency is brought in via `@preconcurrency import` because it is not yet `Sendable`-clean; preserve that import attribute when touching files that import `AppStoreConnect_Swift_SDK`.
- `mise.toml` pins `swift = 6.1.1`, `swiftlint = latest`, and `executor-cli 0.22.0`. Run `mise install` in a fresh checkout.
- Min platforms: iOS 14, macOS 11.

## Common commands

```bash
swift build                                  # build the library
swift test                                   # run all tests (Swift Testing)
swift test --filter AppleDeveloperAPITests.example   # run a single test by name
swiftlint                                    # lint (installed via mise)
swift package resolve                        # refresh Package.resolved
swift package clean                          # wipe .build
```

There is no Xcode project or workspace — open `Package.swift` directly in Xcode if needed. Tests use the Swift Testing framework (`@Test`, `#expect`), not XCTest.

## Architecture

The public surface lives in `Sources/AppleDeveloperAPI/AppleDeveloperAPI.swift` and is intentionally thin:

- `AppleDeveloper.Factory` — namespaced factory that builds `APIConfiguration` (from `issuerID` / `privateKeyID` / `privateKey`) and the underlying `APIProvider` from the upstream SDK. This is the only place auth/config construction should happen.
- `AppStoreConnectAPI` (protocol, `Sendable`) — public contract describing the wrapper's capabilities (`fetchBundleIds`, `fetchProfile`, `fetchCertificate`). All async, all throwing.
- `AppleDeveloperAPIDefault` — internal implementation that holds an `APIProvider` and translates wrapper calls into `APIEndpoint.v1.*` requests on the upstream SDK.

When adding new endpoints, follow the same shape: extend `AppStoreConnectAPI` with an `async throws` method, implement it in `AppleDeveloperAPIDefault` by composing `APIEndpoint.v1.…` requests, and keep the wrapper Sendable. Per the project conventions, the implementation type uses a `Default` suffix rather than `Impl`.
