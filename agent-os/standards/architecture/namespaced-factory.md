---
name: Namespaced Factory
description: AppleDeveloper.Factory is the only seam where upstream SDK types (APIConfiguration, APIProvider) are constructed.
type: architecture
---

# Namespaced Factory

All construction of upstream SDK types (`APIConfiguration`, `APIProvider`)
goes through `AppleDeveloper.Factory` — a caseless enum used as a namespace.

```swift
public enum AppleDeveloper {
    public enum Factory {
        static func createConfiguration(
            issuerID: String, privateKeyID: String, privateKey: String
        ) throws -> APIConfiguration { ... }

        static func createProvider(
            usingConfiguration configuration: APIConfiguration
        ) -> APIProvider { ... }
    }
}
```

- Caseless `enum`, not a `struct` — non-instantiable namespace.
- Only place JWT credentials touch SDK types; no raw `APIConfiguration(...)` elsewhere.
- Goal: grow a `make(...) -> any AppStoreConnectAPI` so callers never see SDK types.
- Until that exists, Factory still returns SDK primitives — but no other call site should.
