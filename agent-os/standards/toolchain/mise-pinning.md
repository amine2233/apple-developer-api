---
name: mise-Pinned Toolchain
description: Toolchain versions live in mise.toml; mise install is the bootstrap step; mise.toml and .swift-version must agree.
type: toolchain
---

# mise-Pinned Toolchain

Toolchain versions are pinned in `mise.toml`. Fresh checkouts and CI run
`mise install` before any other command.

```toml
# mise.toml
[tools]
swift = '6.3.1'
"github:executor-cli/executor" = "0.22.0"
```

- `mise install` is required after cloning. CI uses `jdx/mise-action@v2`
  to do the same.
- `mise.toml` and `.swift-version` must match for the Swift entry. Drift
  between them is a bug — fix it in the same commit that bumps the version.
- Bumping a tool: edit `mise.toml`, mirror the change in `.swift-version`
  if it's the Swift entry, run `mise install`, commit.
- Don't pin transitively (e.g., `swift = 'latest'`) — versions stay explicit.
