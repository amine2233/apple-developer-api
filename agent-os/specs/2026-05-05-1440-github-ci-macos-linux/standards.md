# Standards for GitHub CI

The single applicable standard is `toolchain/mise-pinning`, which this
work rewrites. The new content is below — this is what
`agent-os/standards/toolchain/mise-pinning.md` will read after the
change.

---

## toolchain/mise-pinning (after rewrite)

```
---
name: Tool Pinning
description: .swift-version pins Swift; mise.toml pins every other tool. mise install is the bootstrap step for the non-Swift tools.
type: toolchain
---

# Tool Pinning

- **Swift** is pinned in `.swift-version` (read by SPM and CI). It is
  intentionally **not** in `mise.toml` — local devs are free to install
  Swift via Xcode, asdf, official packages, or whatever else; CI uses
  `swift-actions/setup-swift@v2` against `.swift-version`.
- **Every other tool** (swiftlint, executor-cli, future additions) is
  pinned in `mise.toml`. `mise install` is the bootstrap step in fresh
  checkouts and on CI.

```toml
[tools]
"github:executor-cli/executor" = "0.22.0"
```

- Bumping a tool: edit `mise.toml`, run `mise install`, commit.
- Bumping Swift: edit `.swift-version`, run `swift --version` to confirm,
  commit. CI's setup-swift step picks the new version automatically.
- Don't pin transitively (`'latest'`) — versions stay explicit.
```
