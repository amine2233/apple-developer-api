@preconcurrency import AppStoreConnect_Swift_SDK
import Foundation
import Testing
@testable import AppleDeveloperAPI

private let referenceDate = Date(timeIntervalSince1970: 1_800_000_000)

private func makeSDKProfile(
    id: String = "PROFILE-1",
    name: String? = "Acme iOS Dev",
    uuid: String? = "B5DBE8B5-43A0-4E0E-B7CE-1234567890AB",
    platform: AppStoreConnect_Swift_SDK.BundleIDPlatform? = .ios,
    profileType: AppStoreConnect_Swift_SDK.Profile.Attributes.ProfileType? = .iosAppDevelopment,
    profileState: AppStoreConnect_Swift_SDK.Profile.Attributes.ProfileState? = .active,
    expirationDate: Date? = referenceDate,
    bundleIDRelID: String? = "BUNDLE-1",
    certificateRelIDs: [String] = []
) -> AppStoreConnect_Swift_SDK.Profile {
    let attributes = AppStoreConnect_Swift_SDK.Profile.Attributes(
        name: name,
        platform: platform,
        profileType: profileType,
        profileState: profileState,
        profileContent: nil,
        uuid: uuid,
        createdDate: nil,
        expirationDate: expirationDate
    )
    let bundleIDRel = bundleIDRelID.map {
        AppStoreConnect_Swift_SDK.Profile.Relationships.BundleID(
            data: AppStoreConnect_Swift_SDK.Profile.Relationships.BundleID.Data(type: .bundleIDs, id: $0)
        )
    }
    let certData = certificateRelIDs.map {
        AppStoreConnect_Swift_SDK.Profile.Relationships.Certificates.Datum(type: .certificates, id: $0)
    }
    let certRel = AppStoreConnect_Swift_SDK.Profile.Relationships.Certificates(data: certData)
    let relationships = AppStoreConnect_Swift_SDK.Profile.Relationships(
        bundleID: bundleIDRel,
        devices: nil,
        certificates: certRel
    )
    return AppStoreConnect_Swift_SDK.Profile(
        type: .profiles,
        id: id,
        attributes: attributes,
        relationships: relationships
    )
}

private func makeSDKCertificate(
    id: String,
    name: String? = "Acme Dev Cert",
    displayName: String? = "Acme Dev",
    serialNumber: String? = "ABC123",
    type: AppStoreConnect_Swift_SDK.CertificateType? = .iosDevelopment,
    platform: AppStoreConnect_Swift_SDK.BundleIDPlatform? = .ios,
    expirationDate: Date? = referenceDate
) -> AppStoreConnect_Swift_SDK.Certificate {
    let attributes = AppStoreConnect_Swift_SDK.Certificate.Attributes(
        name: name,
        certificateType: type,
        displayName: displayName,
        serialNumber: serialNumber,
        platform: platform,
        expirationDate: expirationDate,
        certificateContent: nil,
        isActivated: true
    )
    return AppStoreConnect_Swift_SDK.Certificate(type: .certificates, id: id, attributes: attributes)
}

@Suite("Profile mapping")
struct ProfileMappingTests {
    @Test
    func succeedsForValidSDKObject() throws {
        let sdk = makeSDKProfile(certificateRelIDs: ["CERT-1", "CERT-2"])
        let profile = try Profile(sdk: sdk)

        #expect(profile.id == "PROFILE-1")
        #expect(profile.name == "Acme iOS Dev")
        #expect(profile.uuid == "B5DBE8B5-43A0-4E0E-B7CE-1234567890AB")
        #expect(profile.platform == .iOS)
        #expect(profile.profileType == .iOSAppDevelopment)
        #expect(profile.state == .active)
        #expect(profile.expirationDate == referenceDate)
        #expect(profile.bundleIdentifierID == "BUNDLE-1")
        #expect(profile.certificateIDs == ["CERT-1", "CERT-2"])
    }

    @Test
    func throwsWhenAttributesMissing() {
        let sdk = AppStoreConnect_Swift_SDK.Profile(
            type: .profiles,
            id: "PROFILE-X",
            attributes: nil,
            relationships: nil
        )
        do {
            _ = try Profile(sdk: sdk)
            Issue.record("Expected throw, got success")
        } catch let AppleDeveloperError.decodingFailure(field, _) {
            #expect(field == "attributes")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func throwsWhenNameMissing() {
        let sdk = makeSDKProfile(name: nil)
        do {
            _ = try Profile(sdk: sdk)
            Issue.record("Expected throw, got success")
        } catch let AppleDeveloperError.decodingFailure(field, _) {
            #expect(field == "name")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func throwsWhenExpirationDateMissing() {
        let sdk = makeSDKProfile(expirationDate: nil)
        do {
            _ = try Profile(sdk: sdk)
            Issue.record("Expected throw, got success")
        } catch let AppleDeveloperError.decodingFailure(field, _) {
            #expect(field == "expirationDate")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

@Suite("Certificate mapping")
struct CertificateMappingTests {
    @Test
    func succeedsForValidSDKObject() throws {
        let sdk = makeSDKCertificate(id: "CERT-9")
        let cert = try Certificate(sdk: sdk)

        #expect(cert.id == "CERT-9")
        #expect(cert.name == "Acme Dev Cert")
        #expect(cert.displayName == "Acme Dev")
        #expect(cert.serialNumber == "ABC123")
        #expect(cert.certificateType == .iOSDevelopment)
        #expect(cert.platform == .iOS)
        #expect(cert.expirationDate == referenceDate)
    }

    @Test
    func platformIsNilWhenSDKPlatformMissing() throws {
        let sdk = makeSDKCertificate(id: "CERT-X", platform: nil)
        let cert = try Certificate(sdk: sdk)
        #expect(cert.platform == nil)
    }

    @Test
    func throwsWhenSerialNumberMissing() {
        let sdk = makeSDKCertificate(id: "CERT-X", serialNumber: nil)
        do {
            _ = try Certificate(sdk: sdk)
            Issue.record("Expected throw, got success")
        } catch let AppleDeveloperError.decodingFailure(field, _) {
            #expect(field == "serialNumber")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

@Suite("ProfileDetails hydration")
struct ProfileDetailsHydrationTests {
    private func makeResponse(
        profile: AppStoreConnect_Swift_SDK.Profile,
        certificates: [AppStoreConnect_Swift_SDK.Certificate]
    ) -> AppStoreConnect_Swift_SDK.ProfileResponse {
        let included = certificates
            .map { AppStoreConnect_Swift_SDK.ProfileResponse.IncludedItem.certificate($0) }
        return AppStoreConnect_Swift_SDK.ProfileResponse(
            data: profile,
            included: included,
            links: AppStoreConnect_Swift_SDK.DocumentLinks(this: "https://example.test/profiles/PROFILE-1")
        )
    }

    @Test
    func hydratesCertificatesFromIncluded() throws {
        let profile = makeSDKProfile(certificateRelIDs: ["CERT-1", "CERT-2"])
        let cert1 = makeSDKCertificate(id: "CERT-1", name: "First")
        let cert2 = makeSDKCertificate(id: "CERT-2", name: "Second")

        let details = try ProfileDetails.make(from: makeResponse(
            profile: profile,
            certificates: [cert1, cert2]
        ))

        #expect(details.profile.id == "PROFILE-1")
        #expect(details.certificates.map(\.id) == ["CERT-1", "CERT-2"])
        #expect(details.certificates.map(\.name) == ["First", "Second"])
    }

    @Test
    func hydratesEmptyWhenNoCertRelationships() throws {
        let profile = makeSDKProfile(certificateRelIDs: [])
        let details = try ProfileDetails.make(from: makeResponse(profile: profile, certificates: []))

        #expect(details.certificates.isEmpty)
    }

    @Test
    func throwsWhenIncludedMissingACert() {
        let profile = makeSDKProfile(certificateRelIDs: ["CERT-1", "CERT-MISSING"])
        let cert1 = makeSDKCertificate(id: "CERT-1")

        do {
            _ = try ProfileDetails.make(from: makeResponse(profile: profile, certificates: [cert1]))
            Issue.record("Expected throw, got success")
        } catch let AppleDeveloperError.unhydratedRelationship(name, missingIDs) {
            #expect(name == "certificates")
            #expect(missingIDs == ["CERT-MISSING"])
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

@Suite("BundleIDs response → profiles")
struct BundleIDsResponseMappingTests {
    @Test
    func extractsProfilesFromIncluded() throws {
        let bundle = AppStoreConnect_Swift_SDK.BundleID(
            type: .bundleIDs,
            id: "BUNDLE-1",
            attributes: nil,
            relationships: nil
        )
        let profile1 = makeSDKProfile(id: "PROFILE-1", name: "Dev")
        let profile2 = makeSDKProfile(id: "PROFILE-2", name: "Store", profileType: .iosAppStore)

        let response = AppStoreConnect_Swift_SDK.BundleIDsResponse(
            data: [bundle],
            included: [
                .profile(profile1),
                .profile(profile2)
            ],
            links: AppStoreConnect_Swift_SDK.PagedDocumentLinks(this: "https://example.test/bundleIds")
        )

        let profiles = try BundleIDsResponseMapping.extractProfiles(from: response)

        #expect(profiles.map(\.id) == ["PROFILE-1", "PROFILE-2"])
        #expect(profiles.map(\.profileType) == [.iOSAppDevelopment, .iOSAppStore])
    }

    @Test
    func returnsEmptyWhenNoIncluded() throws {
        let response = AppStoreConnect_Swift_SDK.BundleIDsResponse(
            data: [],
            included: nil,
            links: AppStoreConnect_Swift_SDK.PagedDocumentLinks(this: "https://example.test/bundleIds")
        )

        let profiles = try BundleIDsResponseMapping.extractProfiles(from: response)
        #expect(profiles.isEmpty)
    }
}
