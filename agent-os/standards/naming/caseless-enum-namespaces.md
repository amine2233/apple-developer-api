---
name: Caseless-Enum Namespaces
description: Namespaces are caseless enums (never struct/class); group related helpers; max 2 levels of nesting.
type: naming
---

# Caseless-Enum Namespaces

Namespaces are caseless `enum`s — never `struct` or `class`. Used to
group related helpers, factories, and constants.

```swift
public enum AppleDeveloper {
    public enum Factory {
        static func createConfiguration(...) throws -> APIConfiguration { ... }
        static func createProvider(...) -> APIProvider { ... }
    }
}
```

- Use a caseless `enum` so the namespace can't be instantiated.
- Group helpers into a namespace as soon as 2+ naturally cluster (factories, formatters, codes).
- Maximum depth is 2 levels (e.g., `AppleDeveloper.Factory`). If you reach for a third level, the API needs restructuring.
- Don't use `struct` for namespacing — it's instantiable and adds an empty initializer to the API.
- Don't use `class` for namespacing — it adds reference semantics for no reason.
