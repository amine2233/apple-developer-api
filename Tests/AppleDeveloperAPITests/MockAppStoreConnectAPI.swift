import Foundation
@testable import AppleDeveloperAPI

struct MockAppStoreConnectAPI: AppStoreConnectAPI {
    var profiles: [Profile] = []
    var detailsByID: [String: ProfileDetails] = [:]
    var notFoundProfileIDs: Set<String> = []
    var certificatesByID: [String: Certificate] = [:]

    func fetchProfiles(forBundleIdentifier _: String) async throws -> [Profile] {
        profiles
    }

    func fetchProfileDetails(id: String) async throws -> ProfileDetails {
        if notFoundProfileIDs.contains(id) {
            throw AppleDeveloperError.resourceNotFound(kind: "profile", id: id)
        }
        guard let details = detailsByID[id] else {
            throw AppleDeveloperError.resourceNotFound(kind: "profile", id: id)
        }

        return details
    }

    func fetchCertificate(id: String) async throws -> Certificate {
        guard let cert = certificatesByID[id] else {
            throw AppleDeveloperError.resourceNotFound(kind: "certificate", id: id)
        }

        return cert
    }
}
