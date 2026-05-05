---
name: Value-Type Implementations
description: Default impls are structs with private let stored dependencies; use actor (never class) when value semantics don't fit.
type: concurrency
---

# Value-Type Implementations

Default implementations are `struct`s with `private let` stored
dependencies, so `Sendable` conformance is automatic.

```swift
struct AppleDeveloperAPIDefault: AppStoreConnectAPI {
    private let provider: APIProvider

    init(provider: APIProvider) {
        self.provider = provider
    }
    ...
}
```

- `*Default` impls are `struct`. `class` is not used in this package.
- If a `struct` won't model the required behavior, use an `actor` — never a `class`.
- Dependencies are stored as `private let`. `var` is allowed for local mutable
  state, but the type still has to satisfy Sendable (or be inside an actor).
- No shared mutable state across threads — that's what actors are for.
