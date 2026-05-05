# Standards for `BundleArtifactsExporter`

The following standards apply to this work. (Same set the wrapper itself was
written against — included here for spec self-containment.)

---

## architecture/sdk-seam-isolation

The upstream `AppStoreConnect_Swift_SDK` is treated as a non-Sendable
external dependency. Its surface is contained behind the wrapper.

- `@preconcurrency import` only in files that actually reference SDK types.
  Wrapper files that don't touch the SDK must not import it at all.
- Default surface deals in wrapper / domain types only — no SDK type appears
  in protocol method signatures.
- `APIProvider` is stored as `private` inside `*Default`.

Application: only `BundleArtifactsExporterDefault.swift` imports the SDK in
this work; the protocol and summary live in their own SDK-free files.

---

## architecture/protocol-default-pair

Public capabilities are exposed as a `Sendable` protocol with the descriptive
name; the primary production implementation is an internal `struct` with a
`Default` suffix.

Application: `BundleArtifactsExporter` (public protocol) +
`BundleArtifactsExporterDefault` (internal struct).

---

## architecture/namespaced-factory

All construction of upstream SDK types goes through `AppleDeveloper.Factory`
— a caseless enum used as a namespace. Goal: grow `make(...)` methods that
return wrapper types, so callers never see SDK types.

Application: adds `Factory.makeArtifactExporter(issuerID:privateKeyID:privateKey:) -> any BundleArtifactsExporter`.

---

## concurrency/async-throws-contract

Every public wrapper method is `async throws`. No callbacks, no Combine,
no `Result`-returning variants.

Application: `exportArtifacts(forBundleIdentifier:to:) async throws -> ArtifactExportSummary`.

---

## concurrency/sendable-protocols

All public protocols inherit `Sendable`. All types in their method
signatures (parameters, returns, errors) are themselves `Sendable`.

Application: protocol is Sendable; `ArtifactExportSummary` is Sendable;
return URLs are value types.

---

## concurrency/value-type-impls

Default implementations are `struct`s with `private let` stored
dependencies, so `Sendable` conformance is automatic.

Application: `BundleArtifactsExporterDefault` is a `struct` holding
`private let provider: APIProvider`.

---

## naming/single-error-type

The `AppleDeveloperAPI` module exposes exactly one error type:
`public enum AppleDeveloperError: Error`. All throwing APIs in the module
throw this type. Add a `case` rather than introducing a sibling Error type.

Application: adds `.fileWriteFailure(path: String, underlying: any Error)`
to the existing enum.

---

## naming/any-existentials

Whenever a protocol appears as a property, parameter, or return type,
write `any Protocol`. Implicit existentials are forbidden.

Application: `Factory.makeArtifactExporter(...) -> any BundleArtifactsExporter`.
