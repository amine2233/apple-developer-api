import Foundation

public struct ProfileDetails: Sendable, Identifiable, Hashable {
    public let profile: Profile
    public let certificates: [Certificate]

    public var id: String {
        profile.id
    }

    public init(profile: Profile, certificates: [Certificate]) {
        self.profile = profile
        self.certificates = certificates
    }
}
