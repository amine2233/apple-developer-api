# Standards for Domain-Modeled `AppStoreConnectAPI`

The following standards apply to this work.

---

## architecture/sdk-seam-isolation

The upstream `AppStoreConnect_Swift_SDK` is treated as a non-Sendable
external dependency. Its surface is contained behind the wrapper.

```swift
@preconcurrency import AppStoreConnect_Swift_SDK   // only in files that touch the SDK
import Foundation

struct AppleDeveloperAPIDefault: AppStoreConnectAPI {
    private let provider: APIProvider              // SDK type, kept private
    ...
}
```

- `@preconcurrency import` only in files that actually reference SDK types.
  Wrapper files that don't touch the SDK must not import it at all.
- Default surface (`AppStoreConnectAPI`) deals in wrapper / domain types only —
  no SDK type appears in protocol method signatures.
- `APIProvider` is stored as `private` inside `*Default`. Exposing it is allowed
  only on an explicit advanced/escape-hatch API, never on the default protocol.
- Drop the `@preconcurrency` attribute when the SDK ships full `Sendable` conformance.

---

## architecture/protocol-default-pair

Public capabilities are exposed as a `Sendable` protocol with the descriptive
name; the primary production implementation is an internal `struct` with a
`Default` suffix.

- Protocol is `public` and `Sendable`; impl is `internal` (no access modifier).
- Suffix is `Default` — never `Impl`, `Implementation`, `Concrete`.
- Test doubles may use `Mock`, `Fake`, `Stub` suffixes; only the primary impl uses `Default`.
- Callers depend on `any AppStoreConnectAPI`, never on the concrete type.
- Keeping the impl internal preserves freedom to rename / split / replace it without an API break.

---

## architecture/namespaced-factory

All construction of upstream SDK types (`APIConfiguration`, `APIProvider`)
goes through `AppleDeveloper.Factory` — a caseless enum used as a namespace.

- Caseless `enum`, not a `struct` — non-instantiable namespace.
- Only place JWT credentials touch SDK types; no raw `APIConfiguration(...)` elsewhere.
- Goal: grow a `make(...) -> any AppStoreConnectAPI` so callers never see SDK types.
- Until that exists, Factory still returns SDK primitives — but no other call site should.

---

## concurrency/async-throws-contract

Every public wrapper method is `async throws`. No callbacks, no Combine,
no `Result`-returning variants.

- Anything touching the SDK is `async throws` — no exceptions.
- Pure helpers (formatters, transforms with no I/O / no failure path) may be sync non-throwing.
- No Combine publishers, no completion-handler callbacks on the public API.
- Errors propagate via `throws`; do not return `Result<…, Error>`.

---

## concurrency/sendable-protocols

All public protocols inherit `Sendable`. All types that appear in their
method signatures (parameters, returns, errors) are themselves `Sendable`.

- Public protocol → `: Sendable`. Non-Sendable protocols stay internal.
- Every parameter / return / thrown error on a Sendable-protocol method is Sendable.
- DTOs default to `struct` with `Sendable` stored properties — automatic conformance.
- If a value isn't Sendable, fix it — don't mark the protocol or method as something else.

---

## concurrency/value-type-impls

Default implementations are `struct`s with `private let` stored
dependencies, so `Sendable` conformance is automatic.

- `*Default` impls are `struct`. `class` is not used in this package.
- If a `struct` won't model the required behavior, use an `actor` — never a `class`.
- Dependencies are stored as `private let`. `var` is allowed for local mutable
  state, but the type still has to satisfy Sendable (or be inside an actor).
- No shared mutable state across threads — that's what actors are for.

---

## naming/single-error-type

The `AppleDeveloperAPI` module exposes exactly one error type:
`public enum AppleDeveloperError: Error`. All throwing APIs in the module
throw this type.

- One Error type per module. No per-feature error enums (`BundleIDError`, `ProfileError`, etc.).
- Name: module name + `Error` suffix → `AppleDeveloperError`.
- `public` and `Sendable`.
- Wrap upstream / SDK errors in a case (e.g., `.providerFailure(underlying:)`) — never re-throw raw SDK error types.
- Add a new `case` rather than introducing a sibling Error type.

---

## naming/any-existentials

Whenever a protocol appears as a property, parameter, or return type,
write `any Protocol`. Implicit existentials (`Protocol` without `any`)
are forbidden.

- Default protocol-typed declarations to `any Protocol`.
- Plain `Protocol` (no `any`) is allowed only inside generic constraints
  like `<T: AppStoreConnectAPI>` — that's not an existential.
- `some Protocol` is reserved for cases where the opaque type really helps
  (compile-time known, single concrete type). Don't reach for it by default.
