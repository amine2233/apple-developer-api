---
name: Existentials Use any
description: Protocol-typed declarations (params, properties, returns) always use `any Protocol`; implicit existentials are forbidden.
type: naming
---

# Existentials Use `any`

Whenever a protocol appears as a property, parameter, or return type,
write `any Protocol`. Implicit existentials (`Protocol` without `any`)
are forbidden.

```swift
// ✅
let api: any AppStoreConnectAPI
func send(api: any AppStoreConnectAPI) async throws { ... }
func makeAPI() -> any AppStoreConnectAPI { ... }

// ❌
let api: AppStoreConnectAPI               // implicit existential
func send(api: AppStoreConnectAPI) { ... } // implicit existential
```

- Default protocol-typed declarations to `any Protocol`.
- Plain `Protocol` (no `any`) is allowed only inside generic constraints
  like `<T: AppStoreConnectAPI>` — that's not an existential.
- `some Protocol` is reserved for cases where the opaque type really helps
  (compile-time known, single concrete type). Don't reach for it by default.
