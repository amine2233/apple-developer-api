@preconcurrency import AppStoreConnect_Swift_SDK
import Foundation

typealias SDKProfile = AppStoreConnect_Swift_SDK.Profile
typealias SDKCertificate = AppStoreConnect_Swift_SDK.Certificate
typealias SDKProfileResponse = AppStoreConnect_Swift_SDK.ProfileResponse
typealias SDKBundleIDsResponse = AppStoreConnect_Swift_SDK.BundleIDsResponse
typealias SDKBundleIDPlatform = AppStoreConnect_Swift_SDK.BundleIDPlatform
typealias SDKCertificateType = AppStoreConnect_Swift_SDK.CertificateType

extension Platform {
    init(sdk: SDKBundleIDPlatform, field: String) throws {
        switch sdk {
        case .ios: self = .iOS
        case .macOs: self = .macOS
        case .universal: self = .universal
        case .services: self = .services
        @unknown default:
            throw AppleDeveloperError.decodingFailure(
                field: field,
                reason: "unrecognized platform \(sdk.rawValue)"
            )
        }
    }
}

extension ProfileType {
    // swiftlint:disable:next cyclomatic_complexity
    init(sdk: SDKProfile.Attributes.ProfileType, field: String) throws {
        switch sdk {
        case .iosAppDevelopment: self = .iOSAppDevelopment
        case .iosAppStore: self = .iOSAppStore
        case .iosAppAdhoc: self = .iOSAppAdHoc
        case .iosAppInhouse: self = .iOSAppInHouse
        case .macAppDevelopment: self = .macAppDevelopment
        case .macAppStore: self = .macAppStore
        case .macAppDirect: self = .macAppDirect
        case .tvosAppDevelopment: self = .tvOSAppDevelopment
        case .tvosAppStore: self = .tvOSAppStore
        case .tvosAppAdhoc: self = .tvOSAppAdHoc
        case .tvosAppInhouse: self = .tvOSAppInHouse
        case .macCatalystAppDevelopment: self = .macCatalystAppDevelopment
        case .macCatalystAppStore: self = .macCatalystAppStore
        case .macCatalystAppDirect: self = .macCatalystAppDirect
        @unknown default:
            throw AppleDeveloperError.decodingFailure(
                field: field,
                reason: "unrecognized profileType \(sdk.rawValue)"
            )
        }
    }
}

extension ProfileState {
    init(sdk: SDKProfile.Attributes.ProfileState, field: String) throws {
        switch sdk {
        case .active: self = .active
        case .invalid: self = .invalid
        @unknown default:
            throw AppleDeveloperError.decodingFailure(
                field: field,
                reason: "unrecognized profileState \(sdk.rawValue)"
            )
        }
    }
}

extension CertificateType {
    // swiftlint:disable:next cyclomatic_complexity
    init(sdk: SDKCertificateType, field: String) throws {
        switch sdk {
        case .applePay: self = .applePay
        case .applePayMerchantIdentity: self = .applePayMerchantIdentity
        case .applePayPspIdentity: self = .applePayPspIdentity
        case .applePayRsa: self = .applePayRSA
        case .developerIDKext: self = .developerIDKext
        case .developerIDKextG2: self = .developerIDKextG2
        case .developerIDApplication: self = .developerIDApplication
        case .developerIDApplicationG2: self = .developerIDApplicationG2
        case .development: self = .development
        case .distribution: self = .distribution
        case .identityAccess: self = .identityAccess
        case .iosDevelopment: self = .iOSDevelopment
        case .iosDistribution: self = .iOSDistribution
        case .macAppDistribution: self = .macAppDistribution
        case .macInstallerDistribution: self = .macInstallerDistribution
        case .macAppDevelopment: self = .macAppDevelopment
        case .passTypeID: self = .passTypeID
        case .passTypeIDWithNfc: self = .passTypeIDWithNFC
        @unknown default:
            throw AppleDeveloperError.decodingFailure(
                field: field,
                reason: "unrecognized certificateType \(sdk.rawValue)"
            )
        }
    }
}

extension Profile {
    init(sdk: SDKProfile) throws {
        let id = sdk.id
        guard let attributes = sdk.attributes else {
            throw AppleDeveloperError.decodingFailure(field: "attributes", reason: "missing")
        }
        guard let name = attributes.name else {
            throw AppleDeveloperError.decodingFailure(field: "name", reason: "missing")
        }
        guard let uuid = attributes.uuid else {
            throw AppleDeveloperError.decodingFailure(field: "uuid", reason: "missing")
        }
        guard let sdkPlatform = attributes.platform else {
            throw AppleDeveloperError.decodingFailure(field: "platform", reason: "missing")
        }
        guard let sdkProfileType = attributes.profileType else {
            throw AppleDeveloperError.decodingFailure(field: "profileType", reason: "missing")
        }
        guard let sdkProfileState = attributes.profileState else {
            throw AppleDeveloperError.decodingFailure(field: "profileState", reason: "missing")
        }
        guard let expirationDate = attributes.expirationDate else {
            throw AppleDeveloperError.decodingFailure(field: "expirationDate", reason: "missing")
        }

        let bundleIdentifierID = sdk.relationships?.bundleID?.data?.id
        let certificateIDs = sdk.relationships?.certificates?.data?.map(\.id) ?? []

        try self.init(
            id: id,
            name: name,
            uuid: uuid,
            platform: Platform(sdk: sdkPlatform, field: "platform"),
            profileType: ProfileType(sdk: sdkProfileType, field: "profileType"),
            state: ProfileState(sdk: sdkProfileState, field: "profileState"),
            expirationDate: expirationDate,
            bundleIdentifierID: bundleIdentifierID,
            certificateIDs: certificateIDs
        )
    }
}

extension Certificate {
    init(sdk: SDKCertificate) throws {
        let id = sdk.id
        guard let attributes = sdk.attributes else {
            throw AppleDeveloperError.decodingFailure(field: "attributes", reason: "missing")
        }
        guard let name = attributes.name else {
            throw AppleDeveloperError.decodingFailure(field: "name", reason: "missing")
        }
        guard let displayName = attributes.displayName else {
            throw AppleDeveloperError.decodingFailure(field: "displayName", reason: "missing")
        }
        guard let serialNumber = attributes.serialNumber else {
            throw AppleDeveloperError.decodingFailure(field: "serialNumber", reason: "missing")
        }
        guard let sdkCertificateType = attributes.certificateType else {
            throw AppleDeveloperError.decodingFailure(field: "certificateType", reason: "missing")
        }
        guard let expirationDate = attributes.expirationDate else {
            throw AppleDeveloperError.decodingFailure(field: "expirationDate", reason: "missing")
        }

        let platform = try attributes.platform.map { try Platform(sdk: $0, field: "platform") }

        try self.init(
            id: id,
            name: name,
            displayName: displayName,
            serialNumber: serialNumber,
            certificateType: CertificateType(sdk: sdkCertificateType, field: "certificateType"),
            platform: platform,
            expirationDate: expirationDate
        )
    }
}

extension ProfileDetails {
    static func make(from response: SDKProfileResponse) throws -> ProfileDetails {
        let profile = try Profile(sdk: response.data)

        var certificateLookup: [String: SDKCertificate] = [:]
        for item in response.included ?? [] {
            if case let .certificate(sdkCert) = item {
                certificateLookup[sdkCert.id] = sdkCert
            }
        }

        var certificates: [Certificate] = []
        var missing: [String] = []
        for certID in profile.certificateIDs {
            if let sdkCert = certificateLookup[certID] {
                try certificates.append(Certificate(sdk: sdkCert))
            } else {
                missing.append(certID)
            }
        }
        if !missing.isEmpty {
            throw AppleDeveloperError.unhydratedRelationship(
                name: "certificates",
                missingIDs: missing
            )
        }

        return ProfileDetails(profile: profile, certificates: certificates)
    }
}

enum BundleIDsResponseMapping {
    static func extractProfiles(from response: SDKBundleIDsResponse) throws -> [Profile] {
        var profiles: [Profile] = []
        for item in response.included ?? [] {
            if case let .profile(sdkProfile) = item {
                try profiles.append(Profile(sdk: sdkProfile))
            }
        }
        return profiles
    }
}
