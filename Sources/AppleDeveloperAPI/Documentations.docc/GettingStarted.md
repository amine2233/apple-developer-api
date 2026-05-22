# Getting Started

Integrate AppleDeveloperAPI into your project and fetch profiles, certificates, or export them to disk.

## Overview

`AppleDeveloperAPI` is a thin, `Sendable`-friendly wrapper around
[appstoreconnect-swift-sdk](https://github.com/AvdLee/appstoreconnect-swift-sdk).
It exposes two high-level clients — ``AppStoreConnectAPI`` for direct queries and
``BundleArtifactsExporter`` for writing provisioning profiles and signing certificates
to disk — both built by ``AppleDeveloper/Factory``.

## Add the package

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/amine2233/apple-developer-api.git", from: "1.0.0")
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "AppleDeveloperAPI", package: "apple-developer-api")
        ]
    )
]
```

Then `import AppleDeveloperAPI` where you need it. Minimum platforms: iOS 14, macOS 11.

## Provide credentials

You need an App Store Connect API key. Create one at
<https://appstoreconnect.apple.com/access/api>, then collect three values:

- **Issuer ID** — shown above the keys table.
- **Key ID** — the 10-character ID next to the key.
- **Private key** — the PEM contents of the downloaded `.p8` file.

> Treat the private key as a secret. Load it from the keychain, an environment
> variable, or a secure file — never commit it.

## Build a client

Use ``AppleDeveloper/Factory/make(issuerID:privateKeyID:privateKey:)`` for read
operations, or ``AppleDeveloper/Factory/makeArtifactExporter(issuerID:privateKeyID:privateKey:)``
to export artifacts to disk.

```swift
import AppleDeveloperAPI

let api = try AppleDeveloper.Factory.make(
    issuerID: ProcessInfo.processInfo.environment["ASC_ISSUER_ID"]!,
    privateKeyID: ProcessInfo.processInfo.environment["ASC_KEY_ID"]!,
    privateKey: ProcessInfo.processInfo.environment["ASC_PRIVATE_KEY"]!
)
```

If credentials are malformed the factory throws
``AppleDeveloperError/invalidConfiguration(reason:)``.

## Fetch profiles and certificates

All client methods are `async throws`:

```swift
let profiles = try await api.fetchProfiles(forBundleIdentifier: "com.example.MyApp")

for profile in profiles {
    let details = try await api.fetchProfileDetails(id: profile.id)
    for certificateID in details.certificateIDs {
        let certificate = try await api.fetchCertificate(id: certificateID)
        print(certificate.name)
    }
}
```

## Export artifacts to disk

`BundleArtifactsExporter` writes `.mobileprovision` and `.cer` files into the
output directory and returns an ``ArtifactExportSummary`` describing what landed
where.

```swift
let exporter = try AppleDeveloper.Factory.makeArtifactExporter(
    issuerID: issuerID,
    privateKeyID: keyID,
    privateKey: privateKey
)

let summary = try await exporter.exportArtifacts(
    forBundleIdentifier: "com.example.MyApp",
    to: URL(fileURLWithPath: "./out"),
    platforms: [.iOS, .macOS],
    distributionKinds: [.development, .distribution]
)

print("Wrote \(summary.profileFiles.count) profiles, \(summary.certificateFiles.count) certs")
```

The convenience overload `exportArtifacts(forBundleIdentifier:to:)` uses the
defaults `[.iOS, .macOS]` and `[.development, .distribution]`.

## Handle errors

Every failure path funnels through ``AppleDeveloperError`` so you can branch on a
single type:

```swift
do {
    _ = try await api.fetchProfiles(forBundleIdentifier: bundleID)
} catch let error as AppleDeveloperError {
    switch error {
    case .resourceNotFound(let kind, let id):
        print("Missing \(kind) (\(id))")
    case .providerFailure(let underlying):
        print("Upstream SDK failed: \(underlying)")
    default:
        print(error)
    }
}
```

## Topics

### Entry point
- ``AppleDeveloper``
- ``AppleDeveloper/Factory``

### Clients
- ``AppStoreConnectAPI``
- ``BundleArtifactsExporter``

### Filtering
- ``Platform``
- ``DistributionKind``

### Errors
- ``AppleDeveloperError``
