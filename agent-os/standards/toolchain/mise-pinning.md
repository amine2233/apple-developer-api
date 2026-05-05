---
name: mise-Pinned Toolchain
description: Toolchain versions live in mise.toml; mise install is the bootstrap step; mise.toml and .swift-version must agree.
type: toolchain
---

# mise-Pinned Toolchain

Toolchain versions are pinned in `mise.toml`. Fresh checkouts run
`mise install` before any other command.

```toml
# mise.toml
[tools]
swift = '6.1.1'
swiftlint = 'latest'
"github:executor-cli/executor" = "0.22.0"
```

- `mise install` is required after cloning. No manual `swift`/`swiftlint` install paths.
- `mise.toml` and `.swift-version` must match. Drift between them is a bug — fix it in the same commit that bumps the version.
- Bumping a tool: edit `mise.toml`, mirror the change in `.swift-version` if applicable, run `mise install`, commit both.
- Don't pin transitively (e.g., `swift = 'latest'`) — versions stay explicit.
