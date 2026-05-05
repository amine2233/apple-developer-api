---
name: Single Error Type per Module
description: One public Sendable Error enum per module (AppleDeveloperError); wrap SDK errors in a case rather than re-throwing.
type: naming
---

# Single Error Type per Module

The `AppleDeveloperAPI` module exposes exactly one error type:
`public enum AppleDeveloperError: Error`. All throwing APIs in the module
throw this type.

```swift
public enum AppleDeveloperError: Error, Sendable {
    case invalidConfiguration(reason: String)
    case providerFailure(underlying: Error)
    // ... add cases here as needs arise
}
```

- One Error type per module. No per-feature error enums (`BundleIDError`, `ProfileError`, etc.).
- Name: module name + `Error` suffix → `AppleDeveloperError`.
- `public` and `Sendable`.
- Wrap upstream / SDK errors in a case (e.g., `.providerFailure(underlying:)`) — never re-throw raw SDK error types.
- Add a new `case` rather than introducing a sibling Error type.
