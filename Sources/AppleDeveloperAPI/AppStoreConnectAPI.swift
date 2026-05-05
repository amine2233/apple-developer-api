import Foundation

public protocol AppStoreConnectAPI: Sendable {
    func fetchProfiles(forBundleIdentifier bundleIdentifier: String) async throws -> [Profile]
    func fetchProfileDetails(id: String) async throws -> ProfileDetails
    func fetchCertificate(id: String) async throws -> Certificate
}
