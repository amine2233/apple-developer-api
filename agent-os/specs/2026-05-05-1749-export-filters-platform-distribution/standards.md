# Standards for Export Filters

## architecture/sdk-seam-isolation

The upstream `AppStoreConnect_Swift_SDK` is treated as a non-Sendable
external dependency. Its surface is contained behind the wrapper.

Application: `BundleArtifactsExporterDefault.swift` (refactored here)
remains SDK-free. The new `Models/DistributionKind.swift` is a plain
Swift enum.

## architecture/protocol-default-pair

Public capabilities are exposed as a `Sendable` protocol with the
descriptive name; the primary production implementation is an internal
`struct` with a `Default` suffix.

Application: 4-arg method added to the public protocol; 2-arg
convenience overload via a public extension. Internal `*Default` impl
holds all the filter logic.

## concurrency/async-throws-contract

Every public wrapper method is `async throws`. No callbacks, no
Combine, no `Result`.

Application: both 4-arg and 2-arg overloads of `exportArtifacts` are
`async throws`.

## concurrency/sendable-protocols

All public protocols inherit `Sendable`. All types in their method
signatures are themselves `Sendable`.

Application: `DistributionKind: Sendable, Hashable, CaseIterable`.
`Set<Platform>` and `Set<DistributionKind>` are Sendable. `Platform`
already conforms.

## naming/single-error-type

The `AppleDeveloperAPI` module exposes exactly one error type
(`AppleDeveloperError`).

Application: zero new error cases. Reuses existing `.resourceNotFound`.

## naming/any-existentials

Always `any Protocol` for existentials.

Application: unchanged.
