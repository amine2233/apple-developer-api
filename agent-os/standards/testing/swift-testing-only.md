---
name: Swift Testing Only
description: All tests use Swift Testing (@Test, #expect); no XCTest, no Quick/Nimble, no third-party matcher DSLs.
type: testing
---

# Swift Testing Only

All tests use the Swift Testing framework. No XCTest, no Quick, no Nimble.

```swift
import Testing
@testable import AppleDeveloperAPI

@Test
func fetchesBundleId() async throws {
    // ... use #expect / #require
}
```

- Imports: `import Testing` (+ `@testable import AppleDeveloperAPI` when needed).
- Use `@Test`, `@Suite`, `#expect`, `#require`. No `XCTAssert*`, no `setUp/tearDown`.
- No XCTest target — even for capabilities Swift Testing doesn't have yet. Wait or work around.
- No Quick / Nimble / third-party matcher DSLs.
- Run a single test by name: `swift test --filter AppleDeveloperAPITests.<testName>`.
