@preconcurrency import AppStoreConnect_Swift_SDK
import Foundation

public enum AppleDeveloper {
    public enum Factory {
        static func createConfiguration(
            issuerID: String,
            privateKeyID: String,
            privateKey: String
        ) throws -> APIConfiguration {
            try APIConfiguration(
                issuerID: issuerID,
                privateKeyID: privateKeyID,
                privateKey: privateKey
            )
        }

        static func createProvider(usingConfiguration configuration: APIConfiguration) -> APIProvider {
            APIProvider(configuration: configuration)
        }
    }
}

public protocol AppStoreConnectAPI: Sendable {
    func fetchBundleIds(bundleID: String) async throws
    func fetchProfile(id: String) async throws
    func fetchCertificate(id: String) async throws
}

struct AppleDeveloperAPIDefault: AppStoreConnectAPI {
    private let provider: APIProvider

    init(provider: APIProvider) {
        self.provider = provider
    }

    func fetchBundleIds(bundleID: String) async throws {
        let request = APIEndpoint.v1.bundleIDs.get(
            parameters: APIEndpoint.V1.BundleIDs.GetParameters(
                filterIdentifier: [bundleID],
                include: [.profiles]
            )
        )
        let data = try await provider.request(request).data
        print("Did fetch \(data.count) apps")
    }

    func fetchProfile(id: String) async throws {
        let request = APIEndpoint.v1.profiles.get(
            parameters: APIEndpoint.V1.Profiles.GetParameters(
            )
        )
        let data = try await provider.request(request).data
        print("Did fetch \(data.count) apps")
    }

    func fetchCertificate(id: String) async throws {
        let request = APIEndpoint.v1.certificates.get(
            parameters: APIEndpoint.V1.Certificates.GetParameters(
            )
        )
        let data = try await provider.request(request).data
        print("Did fetch \(data.count) apps")
    }
}
