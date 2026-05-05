# GitHub CI on macOS + Linux — Shaping Notes

## Scope

Add a single GitHub Actions workflow at `.github/workflows/ci.yml` that
builds and tests the package on `macos-latest` and `ubuntu-latest`
runners. Triggered by pull requests and pushes to `main`. Swift comes
from `swift-actions/setup-swift@v2` against `.swift-version`. mise
provides everything else via `jdx/mise-action@v2`.

## Decisions

- Drop `swift = '6.3.1'` from `mise.toml`. `.swift-version` (already
  `6.3.1`) becomes the canonical Swift pin.
- Keep `executor-cli` (and any future tools) in `mise.toml`.
- CI uses `swift-actions/setup-swift@v2` on both runners, version
  `6.3.1` (matching `.swift-version`).
- CI uses `jdx/mise-action@v2` to install non-Swift tools.
- Rewrite `agent-os/standards/toolchain/mise-pinning.md` to encode the
  new split: Swift in `.swift-version`, everything else in `mise.toml`.
- No swiftlint in CI.
- No SPM caching for now (keep workflow minimal).
- No `mise run smoke` / `mise run export` in CI (require ASC creds).
- Triggers: `pull_request` + `push` to `main`. Concurrency: cancel
  in-progress on the same ref.
- Matrix: `[macos-latest, ubuntu-latest]`, `fail-fast: false`.

## Context

- **Visuals:** None.
- **References:** `swift-actions/setup-swift@v2`, `jdx/mise-action@v2`,
  the package's `Package.swift` (cross-platform deps), unit tests
  (Linux-safe — `FileManager.default.temporaryDirectory` is OK).
- **Product alignment:** N/A.

## Standards Applied

- `toolchain/mise-pinning` — rewritten as part of this work to reflect
  the new policy.
- All other standards unaffected.
