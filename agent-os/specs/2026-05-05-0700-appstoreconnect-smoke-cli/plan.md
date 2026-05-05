# Plan — `appstoreconnect-smoke` Executable Target

## Context

Unit tests under `Tests/AppleDeveloperAPITests/` cover the SDK→domain mapping
layer with fabricated SDK fixtures, but they don't prove the wrapper actually
talks to App Store Connect. We need a manually-runnable smoke test that hits
real ASC with a `.p8` JWT key and reports whether the three repository
methods work end-to-end.

This is dev-only tooling. It does not run in CI and is not part of `swift test`.

## Decisions locked with the user

- **Target type:** SPM `.executableTarget`, runnable via `swift run`.
- **Argument parsing:** inline (no new package dependency).
- **Credentials:** env vars by default, CLI flags override.
- **Private key:** path or inline; path wins if both supplied.
- **Target name:** `appstoreconnect-smoke`.
- **Flow:** one-shot pipeline (`fetchProfiles` → `fetchProfileDetails` → `fetchCertificate`).
- **executor-cli:** unrelated to this work; no shim added.

## Critical files

Existing:
- `Sources/AppleDeveloperAPI/AppleDeveloperAPI.swift` — gain a public
  `Factory.make(...) -> any AppStoreConnectAPI`.
- `Package.swift` — add a new executable target.

New:
- `Sources/appstoreconnect-smoke/AppStoreConnectSmoke.swift` — the CLI
  (`@main` entry, env/flag parsing, pipeline, pretty-print).

## Tasks

### Task 1 — Save spec documentation

Create `agent-os/specs/2026-05-05-0700-appstoreconnect-smoke-cli/` with:
- `plan.md` — this plan
- `shape.md` — scope + decisions + context
- `standards.md` — full text of relevant standards
- `references.md` — pointers to existing wrapper, SDK auth doc
- `visuals/` — empty

### Task 2 — Add `AppleDeveloper.Factory.make(...)`

Add to `AppleDeveloperAPI.swift`:

```swift
public extension AppleDeveloper.Factory {
    static func make(
        issuerID: String,
        privateKeyID: String,
        privateKey: String
    ) throws -> any AppStoreConnectAPI {
        let cfg = try createConfiguration(
            issuerID: issuerID,
            privateKeyID: privateKeyID,
            privateKey: privateKey
        )
        let provider = createProvider(usingConfiguration: cfg)
        return AppleDeveloperAPIDefault(provider: provider)
    }
}
```

Closes the namespaced-factory standard's open goal: callers no longer
need to handle `APIConfiguration` / `APIProvider` themselves.

`AppleDeveloperAPIDefault` stays internal.

### Task 3 — Wire the executable target

In `Package.swift`:

```swift
.executableTarget(
    name: "appstoreconnect-smoke",
    dependencies: ["AppleDeveloperAPI"],
    path: "Sources/appstoreconnect-smoke"
)
```

No products entry needed — executable targets are discovered automatically
by `swift run`. Min platforms unchanged (the executable is host-only; iOS 14
floor on the library doesn't block macOS execution).

### Task 4 — Implement the CLI

`Sources/appstoreconnect-smoke/AppStoreConnectSmoke.swift`:

- `@main struct AppStoreConnectSmoke { static func main() async }`.
- Reads `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_ID`,
  `APP_STORE_CONNECT_PRIVATE_KEY_PATH`, `APP_STORE_CONNECT_PRIVATE_KEY` env vars.
- Flags override env: `--issuer-id`, `--key-id`, `--private-key-path`,
  `--private-key`. `--private-key-path` wins over `--private-key`.
- Positional arg: bundle identifier (e.g. `com.acme.app`).
- `--help` (or no args / missing creds) prints usage and exits 2.
- Builds api via `AppleDeveloper.Factory.make(...)`.
- Pipeline (each step printed before moving on):
  1. `let profiles = try await api.fetchProfiles(forBundleIdentifier:)` —
     prints `n profiles for <bundleId>:` and a table-ish summary.
  2. If `profiles` is empty, exits 0 with a note. Otherwise picks
     `profiles[0]` and calls `fetchProfileDetails(id: profiles[0].id)`,
     prints profile fields + each cert's id+name.
  3. If `details.certificates` is non-empty, calls
     `fetchCertificate(id: details.certificates[0].id)` and prints it.
- Catches `AppleDeveloperError`, prints a friendly message + the case, exits 1.
- Catches all other errors, exits 1.

Inline parser is ~40 lines: tokenize `CommandLine.arguments`, walk pairs,
build a `Config` struct, fail with a usage error if anything required is missing.

### Task 5 — Verify

```bash
xcrun swift build                                      # target builds
xcrun swift run appstoreconnect-smoke --help           # prints usage, exits 0
xcrun swift run appstoreconnect-smoke                  # missing args, exits 2
swiftlint lint Sources Tests                           # 0 violations
```

No live API call performed in this verification — running the pipeline
against real ASC requires the user's actual credentials and is the whole
point of the tool, but is not part of the build pipeline.

## Standards honored

- `architecture/sdk-seam-isolation` — the executable depends only on
  `AppleDeveloperAPI`; no SDK import in `Sources/appstoreconnect-smoke/`.
- `architecture/protocol-default-pair` — CLI uses `any AppStoreConnectAPI`,
  not the concrete `AppleDeveloperAPIDefault`.
- `architecture/namespaced-factory` — Factory grows the long-promised
  `make(...)` method.
- `concurrency/async-throws-contract` — the CLI's main is async throws.
- `naming/single-error-type` — the CLI catches and reports `AppleDeveloperError`.
- `naming/any-existentials` — `any AppStoreConnectAPI` everywhere.

## Out of scope

- Pagination beyond the first page returned by ASC.
- Output format toggles (always plain text).
- swift-argument-parser dependency.
- executor-cli integration.
- Live test in CI.
- Subcommands or partial-pipeline modes.
- macOS-only `.platforms` constraint (stays as-is).

## Verification

Acceptance:

- `swift build` and `swift run appstoreconnect-smoke --help` both succeed.
- `swiftlint lint Sources Tests` clean.
- The CLI source has no `import AppStoreConnect_Swift_SDK`.
- `AppleDeveloperAPIDefault` remains `internal`.

Manual end-to-end (requires real ASC credentials, not part of CI):

```bash
export APP_STORE_CONNECT_ISSUER_ID=...
export APP_STORE_CONNECT_KEY_ID=...
export APP_STORE_CONNECT_PRIVATE_KEY_PATH=~/path/AuthKey_KEYID.p8
swift run appstoreconnect-smoke com.acme.app
```

Should print: profiles list, then chosen profile details with cert IDs,
then the first hydrated certificate.
