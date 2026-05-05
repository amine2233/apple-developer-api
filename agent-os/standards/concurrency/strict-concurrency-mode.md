---
name: Strict Concurrency Mode
description: Package.swift is locked at swiftLanguageModes [.v6]; fix diagnostics at the source rather than downgrading or suppressing.
type: concurrency
---

# Strict Concurrency Mode

`Package.swift` is locked at `swiftLanguageModes: [.v6]`. Strict concurrency
diagnostics get fixed at the source — never suppressed, never downgraded.

```swift
// Package.swift
swiftLanguageModes: [.v6]
```

- Do not lower to `.v5` or mixed mode. The mode is non-negotiable.
- Fix diagnostics by adding `Sendable`, actor isolation, or restructuring data.
- `@preconcurrency` is reserved for the upstream SDK import boundary
  (see `sdk-seam-isolation.md`). Never use it to silence first-party warnings.
- New dependencies must build cleanly under `.v6`, or be wrapped behind a
  `@preconcurrency` import at a single seam.
