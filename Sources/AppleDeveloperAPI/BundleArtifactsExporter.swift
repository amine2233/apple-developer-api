import Foundation

public protocol BundleArtifactsExporter: Sendable {
    func exportArtifacts(
        forBundleIdentifier bundleIdentifier: String,
        to outputDirectory: URL
    ) async throws -> ArtifactExportSummary
}
