import Foundation

public struct Profile: Sendable, Identifiable, Hashable {
    public let id: String
    public let uuid: String
    public let name: String
    public let platform: Platform
    public let content: Data

    public init(
        id: String,
        uuid: String,
        name: String,
        platform: Platform,
        content: Data
    ) {
        self.id = id
        self.uuid = uuid
        self.name = name
        self.platform = platform
        self.content = content
    }
}
