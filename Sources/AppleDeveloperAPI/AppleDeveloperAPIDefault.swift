@preconcurrency import AppStoreConnect_Swift_SDK
import Foundation

struct AppleDeveloperAPIDefault: AppStoreConnectAPI {
    private let provider: APIProvider

    init(provider: APIProvider) {
        self.provider = provider
    }

    func fetchProfiles(forBundleIdentifier bundleIdentifier: String) async throws -> [Profile] {
        let request = APIEndpoint.v1.bundleIDs.get(
            parameters: APIEndpoint.V1.BundleIDs.GetParameters(
                filterIdentifier: [bundleIdentifier],
                include: [.profiles]
            )
        )
        let response: AppStoreConnect_Swift_SDK.BundleIDsResponse
        do {
            response = try await provider.request(request)
        } catch {
            throw AppleDeveloperError.providerFailure(underlying: error)
        }
        return try BundleIDsResponseMapping.extractProfiles(from: response)
    }

    func fetchProfileDetails(id: String) async throws -> ProfileDetails {
        let request = APIEndpoint.v1.profiles.id(id).get(
            parameters: APIEndpoint.V1.Profiles.WithID.GetParameters(
                include: [.certificates]
            )
        )
        let response: AppStoreConnect_Swift_SDK.ProfileResponse
        do {
            response = try await provider.request(request)
        } catch {
            throw AppleDeveloperError.providerFailure(underlying: error)
        }
        return try ProfileDetails.make(from: response)
    }

    func fetchCertificate(id: String) async throws -> Certificate {
        let request = APIEndpoint.v1.certificates.id(id).get()
        let response: AppStoreConnect_Swift_SDK.CertificateResponse
        do {
            response = try await provider.request(request)
        } catch {
            throw AppleDeveloperError.providerFailure(underlying: error)
        }
        return try Certificate(sdk: response.data)
    }
}
