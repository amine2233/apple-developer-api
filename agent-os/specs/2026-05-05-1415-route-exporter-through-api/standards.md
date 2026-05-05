# Standards for Route-Exporter-Through-API

The following standards apply to this work.

---

## architecture/sdk-seam-isolation

The upstream `AppStoreConnect_Swift_SDK` is treated as a non-Sendable
external dependency. Its surface is contained behind the wrapper.

- `@preconcurrency import` only in files that actually reference SDK types.
  Wrapper files that don't touch the SDK must not import it at all.
- Default surface deals in wrapper / domain types only — no SDK type
  appears in protocol method signatures.
- `APIProvider` is stored as `private` inside `*Default`.

Application: this work removes the SDK import from
`BundleArtifactsExporterDefault.swift`, restoring the rule.

---

## architecture/protocol-default-pair

Public capabilities are exposed as a `Sendable` protocol with the
descriptive name; the primary production implementation is an internal
`struct` with a `Default` suffix.

Application: exporter depends on `any AppStoreConnectAPI` — `Default`
type stays internal.

---

## architecture/namespaced-factory

All construction of upstream SDK types goes through
`AppleDeveloper.Factory`. Goal: `make(...) -> any AppStoreConnectAPI`
so callers never see SDK types.

Application: `Factory.makeArtifactExporter(...)` calls the existing
`Factory.make(...)` to build the api, then passes it to the exporter.

---

## concurrency/async-throws-contract

Every public wrapper method is `async throws`.

Application: no shape change to existing methods.

---

## concurrency/sendable-protocols

All public protocols inherit `Sendable`. All types in their method
signatures are themselves `Sendable`.

Application: the new `content: Data` field on `Profile` / `Certificate`
is Sendable; the protocol contract is unchanged.

---

## naming/single-error-type

The `AppleDeveloperAPI` module exposes exactly one error type
(`AppleDeveloperError`). Add cases rather than introducing siblings.

Application: this work introduces zero new cases — it reuses the
existing `.resourceNotFound(kind:id:)` for the 404 path.

---

## naming/any-existentials

Always `any Protocol` for existentials.

Application: `any AppStoreConnectAPI` is what the exporter holds and
what `Factory.makeArtifactExporter(...)` returns via the service it
constructs.
