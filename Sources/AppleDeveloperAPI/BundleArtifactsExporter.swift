import Foundation

public protocol BundleArtifactsExporter: Sendable {
    func exportArtifacts(
        forBundleIdentifier bundleIdentifier: String,
        to outputDirectory: URL,
        platforms: Set<Platform>,
        distributionKinds: Set<DistributionKind>
    ) async throws -> ArtifactExportSummary
}

extension BundleArtifactsExporter {
    /// Convenience overload using default filters
    /// (`platforms: [.iOS, .macOS]`, `distributionKinds: [.development, .distribution]`).
    public func exportArtifacts(
        forBundleIdentifier bundleIdentifier: String,
        to outputDirectory: URL
    ) async throws -> ArtifactExportSummary {
        try await exportArtifacts(
            forBundleIdentifier: bundleIdentifier,
            to: outputDirectory,
            platforms: [.iOS, .macOS],
            distributionKinds: [.development, .distribution]
        )
    }
}
