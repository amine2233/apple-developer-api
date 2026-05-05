---
name: SDK Seam Isolation
description: Contain AppStoreConnect_Swift_SDK behind the wrapper; @preconcurrency import only where used; APIProvider stays private.
type: architecture
---

# SDK Seam Isolation

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
