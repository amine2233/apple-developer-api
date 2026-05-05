# Export Filters (platform + distribution kind) — Shaping Notes

## Scope

Add two filter parameters to
`BundleArtifactsExporter.exportArtifacts(...)`:

- `platforms: Set<Platform>` — keep only profiles whose `platform` is in
  the set. Default `[.iOS, .macOS]`.
- `distributionKinds: Set<DistributionKind>` — keep only profiles whose
  distribution kind is in the set. Default `[.development, .distribution]`.

Distribution kind is derived from the certificates attached to a profile,
not from the SDK's `Profile.Attributes.ProfileType` (which would
re-introduce the EXPIRED-style decode trap if Apple adds new profile
types like visionOS variants).

## Decisions

- Filter parameters take `Set<Platform>` / `Set<DistributionKind>`
  (literal match — `.universal` only included if the caller adds it).
- Distribution-kind detection: cert-type heuristic
  (`development`/`iOSDevelopment`/`macAppDevelopment` → dev; other
  signing certs → distribution; non-signing certs ignored).
- Mixed-cert profiles return `Set<DistributionKind>` covering both, so
  the filter checks `kinds.isDisjoint(with: filter)` for inclusion.
- New `DistributionKind` is a public Sendable enum.
- Convenience 2-arg overload on the protocol delegates to the 4-arg
  method using the default filters. Existing call sites unchanged.
- On-disk layout stays flat.
- Smoke CLI is unchanged in this iteration; relies on the convenience
  overload.

## Context

- **Visuals:** None.
- **References:** Existing `Sources/AppleDeveloperAPI/` (Models/Enums.swift,
  Profile.swift, BundleArtifactsExporter*.swift) and the `executor-cli` /
  upstream-SDK behavior we already work around for `profileState`.
- **Product alignment:** N/A.

## Standards Applied

- `architecture/sdk-seam-isolation` — exporter remains SDK-free; new
  `DistributionKind` model has no SDK import.
- `architecture/protocol-default-pair` — 4-arg method on the protocol;
  convenience overload via extension; impl stays internal.
- `concurrency/async-throws-contract` — methods are `async throws`.
- `concurrency/sendable-protocols` — new types are Sendable.
- `naming/single-error-type` — no new error cases.
- `naming/any-existentials` — unchanged.
