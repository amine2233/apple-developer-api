# Standards for `appstoreconnect-smoke` CLI

The following standards apply to this work.

---

## architecture/sdk-seam-isolation

The upstream `AppStoreConnect_Swift_SDK` is treated as a non-Sendable
external dependency. Its surface is contained behind the wrapper.

- `@preconcurrency import` only in files that actually reference SDK types.
  Wrapper files that don't touch the SDK must not import it at all.
- Default surface (`AppStoreConnectAPI`) deals in wrapper / domain types
  only — no SDK type appears in protocol method signatures.
- `APIProvider` is stored as `private` inside `*Default`. Exposing it is
  allowed only on an explicit advanced/escape-hatch API, never on the
  default protocol.

Application here: the new `Sources/appstoreconnect-smoke/` target must
not import `AppStoreConnect_Swift_SDK`. It depends only on the
`AppleDeveloperAPI` library product.

---

## architecture/protocol-default-pair

Public capabilities are exposed as a `Sendable` protocol with the
descriptive name; the primary production implementation is an internal
`struct` with a `Default` suffix.

- Protocol is `public` and `Sendable`; impl is `internal`.
- Suffix is `Default` — never `Impl` / `Implementation` / `Concrete`.
- Callers depend on `any AppStoreConnectAPI`, never on the concrete type.

Application here: the CLI must use `any AppStoreConnectAPI`. Adding a
public `Factory.make(...)` lets us keep `AppleDeveloperAPIDefault` internal.

---

## architecture/namespaced-factory

All construction of upstream SDK types (`APIConfiguration`, `APIProvider`)
goes through `AppleDeveloper.Factory` — a caseless enum used as a
namespace.

- Caseless `enum`, not a `struct` — non-instantiable namespace.
- Goal: grow a `make(...) -> any AppStoreConnectAPI` so callers never see
  SDK types. (This work fulfills that goal.)

Application here: this work adds
`AppleDeveloper.Factory.make(issuerID:privateKeyID:privateKey:) -> any AppStoreConnectAPI`.

---

## concurrency/async-throws-contract

Every public wrapper method is `async throws`. No callbacks, no Combine,
no `Result`-returning variants.

Application here: the CLI's `@main` entry is `static func main() async`,
calling the three `async throws` repository methods.

---

## naming/single-error-type

The `AppleDeveloperAPI` module exposes exactly one error type:
`public enum AppleDeveloperError: Error`. All throwing APIs in the module
throw this type.

Application here: the CLI catches `AppleDeveloperError` and pattern-matches
its cases for friendly messages. Other thrown errors become a generic
"unexpected" message.

---

## naming/any-existentials

Whenever a protocol appears as a property, parameter, or return type,
write `any Protocol`. Implicit existentials are forbidden.

Application here: the CLI declares `let api: any AppStoreConnectAPI`
and `Factory.make` returns `any AppStoreConnectAPI`.
