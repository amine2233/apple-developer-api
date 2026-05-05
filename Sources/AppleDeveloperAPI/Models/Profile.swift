import Foundation

public struct Profile: Sendable, Identifiable, Hashable {
    public let id: String
    public let bundleIdentifierID: String?
    public let certificateIDs: [String]

    public init(
        id: String,
        bundleIdentifierID: String?,
        certificateIDs: [String]
    ) {
        self.id = id
        self.bundleIdentifierID = bundleIdentifierID
        self.certificateIDs = certificateIDs
    }
}
