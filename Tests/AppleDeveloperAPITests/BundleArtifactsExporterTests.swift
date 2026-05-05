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
    content: Data = Data("certbytes".utf8)
) -> Certificate {
    Certificate(
        id: id,
        name: "Acme Dev Cert",
        displayName: displayName,
        serialNumber: "ABC123",
        certificateType: .iOSDevelopment,
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
