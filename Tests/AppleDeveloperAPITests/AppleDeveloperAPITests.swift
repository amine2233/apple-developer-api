@preconcurrency import AppStoreConnect_Swift_SDK
import Foundation
import Testing
@testable import AppleDeveloperAPI

private let referenceDate = Date(timeIntervalSince1970: 1_800_000_000)
private let validProfileBase64 = Data("hello-profile".utf8).base64EncodedString()
private let validCertBase64 = Data("hello-cert".utf8).base64EncodedString()

private func makeSDKProfile(
    id: String = "PROFILE-1",
    name: String? = "Acme iOS Dev",
    uuid: String? = "B5DBE8B5-43A0-4E0E-B7CE-1234567890AB",
    platform: AppStoreConnect_Swift_SDK.BundleIDPlatform? = .ios,
    profileContent: String? = validProfileBase64
) -> AppStoreConnect_Swift_SDK.Profile {
    let attributes = AppStoreConnect_Swift_SDK.Profile.Attributes(
        name: name,
        platform: platform,
        profileType: nil,
        profileState: nil,
        profileContent: profileContent,
        uuid: uuid,
        createdDate: nil,
        expirationDate: nil
    )
    return AppStoreConnect_Swift_SDK.Profile(
        type: .profiles,
        id: id,
        attributes: attributes,
        relationships: nil
    )
}

private func makeSDKCertificate(
    id: String,
    name: String? = "Acme Dev Cert",
    displayName: String? = "Acme Dev",
    serialNumber: String? = "ABC123",
    type: AppStoreConnect_Swift_SDK.CertificateType? = .iosDevelopment,
    platform: AppStoreConnect_Swift_SDK.BundleIDPlatform? = .ios,
    expirationDate: Date? = referenceDate,
    certificateContent: String? = validCertBase64
) -> AppStoreConnect_Swift_SDK.Certificate {
    let attributes = AppStoreConnect_Swift_SDK.Certificate.Attributes(
        name: name,
        certificateType: type,
        displayName: displayName,
        serialNumber: serialNumber,
        platform: platform,
        expirationDate: expirationDate,
        certificateContent: certificateContent,
        isActivated: true
    )
    return AppStoreConnect_Swift_SDK.Certificate(type: .certificates, id: id, attributes: attributes)
}

@Suite("Profile mapping")
struct ProfileMappingTests {
    @Test
    func succeedsForValidSDKObject() throws {
        let sdk = makeSDKProfile()
        let profile = try Profile(sdk: sdk)

        #expect(profile.id == "PROFILE-1")
        #expect(profile.uuid == "B5DBE8B5-43A0-4E0E-B7CE-1234567890AB")
        #expect(profile.name == "Acme iOS Dev")
        #expect(profile.platform == .iOS)
        #expect(String(data: profile.content, encoding: .utf8) == "hello-profile")
    }

    @Test
    func throwsWhenProfileContentMissing() {
        let sdk = makeSDKProfile(profileContent: nil)
        do {
            _ = try Profile(sdk: sdk)
            Issue.record("Expected throw, got success")
        } catch let AppleDeveloperError.decodingFailure(field, _) {
            #expect(field == "profileContent")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func throwsOnInvalidBase64Content() {
        let sdk = makeSDKProfile(profileContent: "not base64!")
        do {
            _ = try Profile(sdk: sdk)
            Issue.record("Expected throw, got success")
        } catch let AppleDeveloperError.decodingFailure(field, reason) {
            #expect(field == "profileContent")
            #expect(reason == "invalid base64")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func throwsWhenUUIDMissing() {
        let sdk = makeSDKProfile(uuid: nil)
        do {
            _ = try Profile(sdk: sdk)
            Issue.record("Expected throw, got success")
        } catch let AppleDeveloperError.decodingFailure(field, _) {
            #expect(field == "uuid")
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
        #expect(String(data: cert.content, encoding: .utf8) == "hello-cert")
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

    @Test
    func throwsWhenCertificateContentMissing() {
        let sdk = makeSDKCertificate(id: "CERT-X", certificateContent: nil)
        do {
            _ = try Certificate(sdk: sdk)
            Issue.record("Expected throw, got success")
        } catch let AppleDeveloperError.decodingFailure(field, _) {
            #expect(field == "certificateContent")
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
        let profile = makeSDKProfile()
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
    func hydratesEmptyWhenNoIncludedCerts() throws {
        let profile = makeSDKProfile()
        let details = try ProfileDetails.make(from: makeResponse(profile: profile, certificates: []))

        #expect(details.certificates.isEmpty)
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
        let profile2 = makeSDKProfile(id: "PROFILE-2", name: "Store")

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
