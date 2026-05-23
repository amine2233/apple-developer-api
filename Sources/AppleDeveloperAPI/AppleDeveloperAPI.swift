@preconcurrency import AppStoreConnect_Swift_SDK
import Foundation

/// Top-level namespace for the AppleDeveloperAPI library.
public enum AppleDeveloper {
    /// Builds the authenticated clients exposed by this library.
    ///
    /// All credentials are App Store Connect API key fields obtained from
    /// <https://appstoreconnect.apple.com/access/api>.
    public enum Factory {
        /// Builds an `APIConfiguration` from raw App Store Connect API key fields.
        ///
        /// - Parameters:
        ///   - issuerID: The issuer ID of the API key.
        ///   - privateKeyID: The key ID of the API key.
        ///   - privateKey: The PEM-encoded private key content.
        /// - Returns: A configuration ready to be passed to ``createProvider(usingConfiguration:)``.
        /// - Throws: ``AppleDeveloperError/invalidConfiguration(reason:)`` if the SDK rejects the inputs.
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

        /// Wraps a configuration in the underlying SDK's `APIProvider`.
        ///
        /// - Parameter configuration: A configuration produced by
        /// ``createConfiguration(issuerID:privateKeyID:privateKey:)``.
        /// - Returns: A provider that can issue authenticated requests.
        public static func createProvider(usingConfiguration configuration: APIConfiguration) -> APIProvider {
            APIProvider(configuration: configuration)
        }

        /// Builds a ready-to-use ``AppStoreConnectAPI`` client from raw credentials.
        ///
        /// Convenience that chains ``createConfiguration(issuerID:privateKeyID:privateKey:)``
        /// and ``createProvider(usingConfiguration:)``.
        ///
        /// - Parameters:
        ///   - issuerID: The issuer ID of the API key.
        ///   - privateKeyID: The key ID of the API key.
        ///   - privateKey: The PEM-encoded private key content.
        /// - Returns: A `Sendable` client conforming to ``AppStoreConnectAPI``.
        /// - Throws: ``AppleDeveloperError/invalidConfiguration(reason:)`` if credentials are rejected.
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

        /// Builds a ``BundleArtifactsExporter`` for downloading profiles and certificates tied to a bundle
        /// ID.
        ///
        /// - Parameters:
        ///   - issuerID: The issuer ID of the API key.
        ///   - privateKeyID: The key ID of the API key.
        ///   - privateKey: The PEM-encoded private key content.
        /// - Returns: An exporter backed by a freshly built ``AppStoreConnectAPI`` client.
        /// - Throws: ``AppleDeveloperError/invalidConfiguration(reason:)`` if credentials are rejected.
        public static func makeArtifactExporter(
            issuerID: String,
            privateKeyID: String,
            privateKey: String
        ) throws -> any BundleArtifactsExporter {
            let api = try make(
                issuerID: issuerID,
                privateKeyID: privateKeyID,
                privateKey: privateKey
            )
            return BundleArtifactsExporterDefault(api: api)
        }
    }
}
