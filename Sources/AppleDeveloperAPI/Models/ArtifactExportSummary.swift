import Foundation

public struct ArtifactExportSummary: Sendable, Hashable {
    public let bundleIdentifier: String
    public let profilesDirectory: URL
    public let certificatesDirectory: URL
    public let profileFiles: [URL]
    public let certificateFiles: [URL]
    public let skippedProfileIDs: [String]

    public init(
        bundleIdentifier: String,
        profilesDirectory: URL,
        certificatesDirectory: URL,
        profileFiles: [URL],
        certificateFiles: [URL],
        skippedProfileIDs: [String] = []
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.profilesDirectory = profilesDirectory
        self.certificatesDirectory = certificatesDirectory
        self.profileFiles = profileFiles
        self.certificateFiles = certificateFiles
        self.skippedProfileIDs = skippedProfileIDs
    }
}
