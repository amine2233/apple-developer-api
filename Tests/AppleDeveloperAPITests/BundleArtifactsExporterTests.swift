import Foundation
import Testing
@testable import AppleDeveloperAPI

private let referenceDate = Date(timeIntervalSince1970: 1_800_000_000)

private func makeTempDir() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("BundleArtifactsExporterTests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makeProfile(
    id: String = "PID",
    uuid: String = "ABC-123",
    platform: Platform = .iOS,
    content: Data = Data("hello".utf8)
) -> Profile {
    Profile(id: id, uuid: uuid, name: "Test Profile", platform: platform, content: content)
}

private func makeCertificate(
    id: String = "CID",
    displayName: String = "Acme Dev",
    certificateType: CertificateType = .iOSDevelopment,
    content: Data = Data("certbytes".utf8)
) -> Certificate {
    Certificate(
        id: id,
        name: "Acme Dev Cert",
        displayName: displayName,
        serialNumber: "ABC123",
        certificateType: certificateType,
        platform: .iOS,
        expirationDate: referenceDate,
        content: content
    )
}

@Suite("Filename sanitization")
struct FilenameSanitizationTests {
    @Test
    func sanitizesColonsAndSlashes() {
        let result = BundleArtifactsExporterDefault.sanitize("Apple Distribution: Acme/Corp")
        #expect(result == "Apple Distribution_ Acme_Corp")
    }

    @Test
    func collapsesRunsOfReplacedChars() {
        let result = BundleArtifactsExporterDefault.sanitize("a//:b")
        #expect(result == "a_b")
    }

    @Test
    func emptyAfterStrip() {
        let result = BundleArtifactsExporterDefault.sanitize(":://\\")
        #expect(result == "")
    }

    @Test
    func trimsLeadingAndTrailingWhitespace() {
        let result = BundleArtifactsExporterDefault.sanitize("  Acme Cert  ")
        #expect(result == "Acme Cert")
    }
}

@Suite("Profile extension selection")
struct ProfileExtensionTests {
    @Test
    func macOSReturnsProvisionprofile() {
        #expect(BundleArtifactsExporterDefault.profileExtension(for: .macOS) == "provisionprofile")
    }

    @Test
    func universalReturnsProvisionprofile() {
        #expect(BundleArtifactsExporterDefault.profileExtension(for: .universal) == "provisionprofile")
    }

    @Test
    func iOSReturnsMobileprovision() {
        #expect(BundleArtifactsExporterDefault.profileExtension(for: .iOS) == "mobileprovision")
    }

    @Test
    func servicesReturnsMobileprovision() {
        #expect(BundleArtifactsExporterDefault.profileExtension(for: .services) == "mobileprovision")
    }
}

@Suite("Profile writer")
struct ProfileWriterTests {
    @Test
    func writesContentAsMobileprovisionForIOS() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let profile = makeProfile(uuid: "ABC-123", platform: .iOS, content: Data("hello".utf8))
        let url = try BundleArtifactsExporterDefault.writeProfile(profile, into: dir)

        #expect(url == dir.appendingPathComponent("ABC-123.mobileprovision"))
        let written = try Data(contentsOf: url)
        #expect(String(data: written, encoding: .utf8) == "hello")
    }

    @Test
    func writesProvisionprofileForMacOS() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let profile = makeProfile(uuid: "MAC-001", platform: .macOS)
        let url = try BundleArtifactsExporterDefault.writeProfile(profile, into: dir)

        #expect(url == dir.appendingPathComponent("MAC-001.provisionprofile"))
    }

    @Test
    func writesProvisionprofileForUniversal() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let profile = makeProfile(uuid: "UNI-001", platform: .universal)
        let url = try BundleArtifactsExporterDefault.writeProfile(profile, into: dir)

        #expect(url == dir.appendingPathComponent("UNI-001.provisionprofile"))
    }
}

@Suite("Certificate writer")
struct CertificateWriterTests {
    @Test
    func writesContentToSanitizedDisplayName() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let cert = makeCertificate(
            id: "CID",
            displayName: "Apple Distribution: Acme/Corp",
            content: Data("certbytes".utf8)
        )
        let url = try BundleArtifactsExporterDefault.writeCertificate(cert, into: dir)

        #expect(url == dir.appendingPathComponent("Apple Distribution_ Acme_Corp.cer"))
        let written = try Data(contentsOf: url)
        #expect(String(data: written, encoding: .utf8) == "certbytes")
    }

    @Test
    func fallsBackToIDWhenDisplayNameSanitizesToEmpty() throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let cert = makeCertificate(id: "CERT-FALLBACK", displayName: ":://\\")
        let url = try BundleArtifactsExporterDefault.writeCertificate(cert, into: dir)

        #expect(url == dir.appendingPathComponent("CERT-FALLBACK.cer"))
    }
}

@Suite("Distribution-kind classifier")
struct DistributionKindClassifierTests {
    @Test
    func developmentCertReturnsDevelopment() {
        let cert = makeCertificate(certificateType: .iOSDevelopment)
        #expect(BundleArtifactsExporterDefault.classify(certs: [cert]) == [.development])
    }

    @Test
    func distributionCertReturnsDistribution() {
        let cert = makeCertificate(certificateType: .iOSDistribution)
        #expect(BundleArtifactsExporterDefault.classify(certs: [cert]) == [.distribution])
    }

    @Test
    func mixedReturnsBoth() {
        let dev = makeCertificate(id: "DEV", certificateType: .iOSDevelopment)
        let dist = makeCertificate(id: "DIST", certificateType: .iOSDistribution)
        #expect(
            BundleArtifactsExporterDefault.classify(certs: [dev, dist])
                == [.development, .distribution]
        )
    }

    @Test
    func developerIDIsDistribution() {
        let cert = makeCertificate(certificateType: .developerIDApplication)
        #expect(BundleArtifactsExporterDefault.classify(certs: [cert]) == [.distribution])
    }

    @Test
    func applePayIsIgnoredAndFallsBackToDistribution() {
        let cert = makeCertificate(certificateType: .applePay)
        #expect(BundleArtifactsExporterDefault.classify(certs: [cert]) == [.distribution])
    }

    @Test
    func noCertsDefaultsToDistribution() {
        #expect(BundleArtifactsExporterDefault.classify(certs: []) == [.distribution])
    }
}

@Suite("Exporter integration filters")
struct ExporterIntegrationFilterTests {
    private func makeExporter(api: MockAppStoreConnectAPI) -> BundleArtifactsExporterDefault {
        BundleArtifactsExporterDefault(api: api)
    }

    private func devCert(id: String = "CERT-DEV") -> Certificate {
        makeCertificate(id: id, displayName: "Dev Cert", certificateType: .iOSDevelopment)
    }

    private func distCert(id: String = "CERT-DIST") -> Certificate {
        makeCertificate(id: id, displayName: "Dist Cert", certificateType: .iOSDistribution)
    }

    @Test
    func keepsOnlyProfilesMatchingPlatformFilter() async throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let iosProfile = makeProfile(id: "P-IOS", uuid: "UUID-IOS", platform: .iOS)
        let macProfile = makeProfile(id: "P-MAC", uuid: "UUID-MAC", platform: .macOS)
        let cert = devCert()

        let mock = MockAppStoreConnectAPI(
            profiles: [iosProfile, macProfile],
            detailsByID: [
                "P-IOS": ProfileDetails(profile: iosProfile, certificates: [cert]),
                "P-MAC": ProfileDetails(profile: macProfile, certificates: [cert])
            ],
            certificatesByID: ["CERT-DEV": cert]
        )

        let summary = try await makeExporter(api: mock).exportArtifacts(
            forBundleIdentifier: "com.acme.app",
            to: dir,
            platforms: [.iOS],
            distributionKinds: [.development, .distribution]
        )

        #expect(summary.profileFiles.count == 1)
        #expect(summary.profileFiles.first?.lastPathComponent == "UUID-IOS.mobileprovision")
        #expect(summary.certificateFiles.count == 1)
    }

    @Test
    func keepsOnlyProfilesMatchingDistributionKind() async throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let devProfile = makeProfile(id: "P-DEV", uuid: "UUID-DEV", platform: .iOS)
        let distProfile = makeProfile(id: "P-DIST", uuid: "UUID-DIST", platform: .iOS)
        let dCert = devCert()
        let xCert = distCert()

        let mock = MockAppStoreConnectAPI(
            profiles: [devProfile, distProfile],
            detailsByID: [
                "P-DEV": ProfileDetails(profile: devProfile, certificates: [dCert]),
                "P-DIST": ProfileDetails(profile: distProfile, certificates: [xCert])
            ],
            certificatesByID: ["CERT-DEV": dCert, "CERT-DIST": xCert]
        )

        let summary = try await makeExporter(api: mock).exportArtifacts(
            forBundleIdentifier: "com.acme.app",
            to: dir,
            platforms: [.iOS, .macOS],
            distributionKinds: [.development]
        )

        #expect(summary.profileFiles.count == 1)
        #expect(summary.profileFiles.first?.lastPathComponent == "UUID-DEV.mobileprovision")
        #expect(summary.certificateFiles.map(\.lastPathComponent) == ["Dev Cert.cer"])
    }

    @Test
    func combinedFiltersIntersect() async throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let iosDev = makeProfile(id: "iOS-DEV", uuid: "U-IDEV", platform: .iOS)
        let iosDist = makeProfile(id: "iOS-DIST", uuid: "U-IDIS", platform: .iOS)
        let macDev = makeProfile(id: "MAC-DEV", uuid: "U-MDEV", platform: .macOS)
        let dCert = devCert()
        let xCert = distCert()

        let mock = MockAppStoreConnectAPI(
            profiles: [iosDev, iosDist, macDev],
            detailsByID: [
                "iOS-DEV": ProfileDetails(profile: iosDev, certificates: [dCert]),
                "iOS-DIST": ProfileDetails(profile: iosDist, certificates: [xCert]),
                "MAC-DEV": ProfileDetails(profile: macDev, certificates: [dCert])
            ],
            certificatesByID: ["CERT-DEV": dCert, "CERT-DIST": xCert]
        )

        let summary = try await makeExporter(api: mock).exportArtifacts(
            forBundleIdentifier: "com.acme.app",
            to: dir,
            platforms: [.iOS],
            distributionKinds: [.development]
        )

        #expect(summary.profileFiles.count == 1)
        #expect(summary.profileFiles.first?.lastPathComponent == "U-IDEV.mobileprovision")
    }

    @Test
    func convenienceOverloadIncludesEverything() async throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let iosDev = makeProfile(id: "iOS-DEV", uuid: "U-IDEV", platform: .iOS)
        let macDist = makeProfile(id: "MAC-DIST", uuid: "U-MDIS", platform: .macOS)
        let dCert = devCert()
        let xCert = distCert()

        let mock = MockAppStoreConnectAPI(
            profiles: [iosDev, macDist],
            detailsByID: [
                "iOS-DEV": ProfileDetails(profile: iosDev, certificates: [dCert]),
                "MAC-DIST": ProfileDetails(profile: macDist, certificates: [xCert])
            ],
            certificatesByID: ["CERT-DEV": dCert, "CERT-DIST": xCert]
        )

        let summary = try await makeExporter(api: mock).exportArtifacts(
            forBundleIdentifier: "com.acme.app",
            to: dir
        )

        #expect(summary.profileFiles.count == 2)
        #expect(summary.certificateFiles.count == 2)
    }

    @Test
    func skippedProfileIDsStillReportedWhenFiltered() async throws {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let iosProfile = makeProfile(id: "P-IOS", uuid: "U-IOS", platform: .iOS)
        let macProfile = makeProfile(id: "P-MAC", uuid: "U-MAC", platform: .macOS)
        let cert = devCert()

        let mock = MockAppStoreConnectAPI(
            profiles: [iosProfile, macProfile],
            detailsByID: [:], // none populated → fetchProfileDetails throws .resourceNotFound
            notFoundProfileIDs: ["P-IOS"], // explicit; the macOS one is filtered out before fetch
            certificatesByID: ["CERT-DEV": cert]
        )

        let summary = try await makeExporter(api: mock).exportArtifacts(
            forBundleIdentifier: "com.acme.app",
            to: dir,
            platforms: [.iOS],
            distributionKinds: [.development, .distribution]
        )

        #expect(summary.profileFiles.isEmpty)
        #expect(summary.certificateFiles.isEmpty)
        #expect(summary.skippedProfileIDs == ["P-IOS"])
    }
}
