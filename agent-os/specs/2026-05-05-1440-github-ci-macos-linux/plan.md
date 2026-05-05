# Plan — GitHub Actions CI on macOS + Linux

## Context

The repo has no CI today. The user wants a GitHub Actions workflow that
builds and tests the package on both macOS and Linux for every PR and
every push to `main`. Two related decisions shape the workflow:

1. **Swift toolchain stops being mise's responsibility.** The user wants
   `swift = '6.3.1'` removed from `mise.toml`. CI installs Swift via
   `swift-actions/setup-swift@v2` (matching `.swift-version`); local devs
   keep using whatever Swift they want (Xcode-bundled, asdf,
   manual install). `.swift-version` (already `6.3.1`) is the new
   canonical Swift pin.
2. **mise still owns everything else.** `executor-cli` (and any future
   tool) stay in `mise.toml`. CI uses `jdx/mise-action@v2` to install
   them.

The `mise-pinning` standard must be updated to reflect this split since
its current text says `mise.toml` and `.swift-version` must agree (i.e.
both pin Swift). New rule: `.swift-version` pins Swift; `mise.toml` pins
everything else.

CI does **not** run swiftlint (per user choice) and does **not** run the
smoke / export tasks (those need ASC credentials, which CI doesn't have).

## Decisions locked with the user

- **Swift on CI**: `swift-actions/setup-swift@v2` with version `6.3.1`
  on both macOS and Linux runners.
- **Tools on CI**: `jdx/mise-action@v2` to install mise-managed tools
  (`executor-cli`).
- **Lint on CI**: skip.
- **Standards update**: rewrite `agent-os/standards/toolchain/mise-pinning.md`
  to encode the new "Swift in `.swift-version`, everything else in mise"
  policy.
- **Triggers**: `pull_request` (any base) + `push` to `main`.
- **Matrix**: `macos-latest`, `ubuntu-latest`. `fail-fast: false`.
- **Concurrency**: cancel in-progress runs on the same ref.

## Critical files

Existing — modify:
- `mise.toml` — drop `swift = '6.3.1'` line. Keep `executor-cli` and the
  tasks/env sections.
- `agent-os/standards/toolchain/mise-pinning.md` — rewrite around the
  Swift-via-`.swift-version` policy.
- `agent-os/standards/index.yml` — only the `description` may need a
  tweak to match.

New:
- `.github/workflows/ci.yml` — the CI workflow.

Reference (read-only):
- `Package.swift` — confirms Swift 6 strict-concurrency expectations and
  cross-platform dependency tree (`swift-asn1`, `swift-crypto`,
  `URLQueryEncoder` all work on Linux).
- `Tests/AppleDeveloperAPITests/` — pure unit tests, no network, no
  filesystem outside `FileManager.default.temporaryDirectory`. Linux-safe.

## Tasks

### Task 1 — Save spec docs

Create `agent-os/specs/2026-05-05-HHMM-github-ci-macos-linux/`:
- `plan.md` — copy of this plan.
- `shape.md` — scope + decisions.
- `standards.md` — the **rewritten** `mise-pinning.md` content.
- `references.md` — pointers to actions used (`swift-actions/setup-swift@v2`,
  `jdx/mise-action@v2`) and to the package files driving CI (Package.swift,
  mise.toml, .swift-version).
- `visuals/` — empty.

### Task 2 — Drop Swift from `mise.toml`

```toml
[tools]
"github:executor-cli/executor" = "0.22.0"
```

(Just remove the `swift = '6.3.1'` line. Leave `[env]`, `[tasks.*]` as-is.)

After: `mise current` should still work; `mise install` should still
succeed (only installing executor-cli).

### Task 3 — Rewrite `mise-pinning.md` standard

New content (replaces the existing body — keep the frontmatter format):

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

Update `agent-os/standards/index.yml`:
- The `mise-pinning` entry's description string. Current:
  `"Toolchain versions live in mise.toml; mise install is the bootstrap step."`
  New: `".swift-version pins Swift; mise.toml pins every other tool; mise install bootstraps."`

### Task 4 — Add `.github/workflows/ci.yml`

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    name: Test (${{ matrix.os }})
    strategy:
      fail-fast: false
      matrix:
        os: [macos-latest, ubuntu-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Swift
        uses: swift-actions/setup-swift@v2
        with:
          swift-version: '6.3.1'

      - name: Show Swift version
        run: swift --version

      - name: Set up mise tools
        uses: jdx/mise-action@v2

      - name: Resolve packages
        run: swift package resolve

      - name: Build (incl. tests)
        run: swift build --build-tests

      - name: Run tests
        run: swift test
```

Notes:
- No SPM cache for now — keep the workflow simple. Add caching later if
  build minutes matter.
- `swift package resolve` is explicit so dependency-fetch failures show
  up as their own step.
- We don't run `mise run smoke` or `mise run export`: those require ASC
  credentials we don't supply on CI.

### Task 5 — Verify locally

```bash
mise install            # should succeed without swift in mise.toml
mise current swift      # should still resolve via .swift-version
xcrun swift build       # local build still works
xcrun swift test        # 25/25 still passes
```

Then commit + push the workflow on a feature branch and confirm both
jobs pass on a real PR.

## Standards honored

- `toolchain/mise-pinning` (after rewrite) — `.swift-version` is the
  canonical Swift pin; everything else stays in `mise.toml`.
- All other standards are unaffected — this is purely tooling.

## Out of scope

- Linting in CI (skipped per user).
- SPM build caching (`actions/cache`).
- Code-coverage upload, codecov, etc.
- Running `mise run test` (which goes through `executor`) — plain
  `swift test` is enough for CI; `mise run test` stays as a dev
  convenience.
- Lint-only job; release tagging; matrix expansion to other Swift versions.
- Adding Linux to `Package.swift`'s `platforms` list — SPM treats that
  list as Apple-only; Linux already works.
- ASC credentials in CI / running export end-to-end.

## Verification

Acceptance:
- New `.github/workflows/ci.yml` triggers on PR + push to `main`.
- Both `Test (macos-latest)` and `Test (ubuntu-latest)` jobs go green
  on a fresh PR.
- `swift = '6.3.1'` is gone from `mise.toml`.
- `.swift-version` still reads `6.3.1`.
- `mise install` (locally) still succeeds — installs executor-cli only.
- `agent-os/standards/toolchain/mise-pinning.md` no longer says
  `mise.toml` and `.swift-version` "must match".
- `agent-os/standards/index.yml` description updated to match.

Verification commands locally:

```bash
mise install
mise current swift                    # 6.3.1 from .swift-version
xcrun swift build                     # green
xcrun swift test                      # 25/25 green
```

After push:

```bash
gh pr create --base main              # opens PR, CI triggers
gh run watch                          # watch jobs go green
```
