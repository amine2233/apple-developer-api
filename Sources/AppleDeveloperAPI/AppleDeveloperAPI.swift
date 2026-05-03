import AppStoreConnect_Swift_SDK
import Foundation

public protocol AppStoreConnectAPI: Sendable {
    func fetchBundleIds(bundleID: String) async throws
    func fetchProfile(id: String) async throws
    func fetchCertificate(id: String) async throws
}

struct AppleDeveloperAPIDefault: AppleDeveloperAPI {
    private let configuration: APIConfiguration
    private let provider: APIProvider

    init(configuration: APIConfiguration) {
        self.configuration = configuration
        self.provider = configuration
    }
}

