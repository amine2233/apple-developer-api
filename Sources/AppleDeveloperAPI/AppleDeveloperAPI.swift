@preconcurrency import AppStoreConnect_Swift_SDK
import Foundation

public enum AppleDeveloper {
    public enum Factory {
        public static func createConfiguration(
            issuerID: String,
            privateKeyID: String,
            privateKey: String
        ) throws -> APIConfiguration {
            do {
                return try APIConfiguration(
                    issuerID: issuerID,
                    privateKeyID: privateKeyID,
                    privateKey: privateKey
                )
            } catch {
                throw AppleDeveloperError.invalidConfiguration(
                    reason: String(describing: error)
                )
            }
        }

        public static func createProvider(usingConfiguration configuration: APIConfiguration) -> APIProvider {
            APIProvider(configuration: configuration)
        }

        public static func make(
            issuerID: String,
            privateKeyID: String,
            privateKey: String
        ) throws -> any AppStoreConnectAPI {
            let configuration = try createConfiguration(
                issuerID: issuerID,
                privateKeyID: privateKeyID,
                privateKey: privateKey
            )
            let provider = createProvider(usingConfiguration: configuration)
            return AppleDeveloperAPIDefault(provider: provider)
        }
    }
}
