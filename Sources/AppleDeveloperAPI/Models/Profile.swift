import Foundation

public struct Profile: Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let uuid: String
    public let platform: Platform
    public let profileType: ProfileType
    public let state: ProfileState
    public let expirationDate: Date
    public let bundleIdentifierID: String?
    public let certificateIDs: [String]

    public init(
        id: String,
        name: String,
        uuid: String,
        platform: Platform,
        profileType: ProfileType,
        state: ProfileState,
        expirationDate: Date,
        bundleIdentifierID: String?,
        certificateIDs: [String]
    ) {
        self.id = id
        self.name = name
        self.uuid = uuid
        self.platform = platform
        self.profileType = profileType
        self.state = state
        self.expirationDate = expirationDate
        self.bundleIdentifierID = bundleIdentifierID
        self.certificateIDs = certificateIDs
    }
}
