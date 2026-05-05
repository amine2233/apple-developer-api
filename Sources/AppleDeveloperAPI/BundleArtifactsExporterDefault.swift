import Foundation

struct BundleArtifactsExporterDefault: BundleArtifactsExporter {
    private let api: any AppStoreConnectAPI

    init(api: any AppStoreConnectAPI) {
        self.api = api
    }

    func exportArtifacts(
        forBundleIdentifier bundleIdentifier: String,
        to outputDirectory: URL
    ) async throws -> ArtifactExportSummary {
        let bundleDir = outputDirectory.appendingPathComponent(bundleIdentifier, isDirectory: true)
        let profilesDir = bundleDir.appendingPathComponent("profiles", isDirectory: true)
        let certificatesDir = bundleDir.appendingPathComponent("certificates", isDirectory: true)
        try Self.makeDirectory(profilesDir)
        try Self.makeDirectory(certificatesDir)

        let profiles = try await api.fetchProfiles(forBundleIdentifier: bundleIdentifier)
        var profileFiles: [URL] = []
        for profile in profiles {
            profileFiles.append(try Self.writeProfile(profile, into: profilesDir))
        }

        var seenCertificateIDs: Set<String> = []
        var certificateFiles: [URL] = []
        var skippedProfileIDs: [String] = []
        for profile in profiles {
            let details: ProfileDetails
            do {
                details = try await api.fetchProfileDetails(id: profile.id)
            } catch let AppleDeveloperError.resourceNotFound(kind, _) where kind == "profile" {
                skippedProfileIDs.append(profile.id)
                continue
            }
            for certificate in details.certificates where seenCertificateIDs.insert(certificate.id).inserted {
                certificateFiles.append(try Self.writeCertificate(certificate, into: certificatesDir))
            }
        }

        return ArtifactExportSummary(
            bundleIdentifier: bundleIdentifier,
            profilesDirectory: profilesDir,
            certificatesDirectory: certificatesDir,
            profileFiles: profileFiles,
            certificateFiles: certificateFiles,
            skippedProfileIDs: skippedProfileIDs
        )
    }
}

extension BundleArtifactsExporterDefault {
    static func makeDirectory(_ url: URL) throws {
        do {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true
            )
        } catch {
            throw AppleDeveloperError.fileWriteFailure(path: url.path, underlying: error)
        }
    }

    static func writeProfile(_ profile: Profile, into directory: URL) throws -> URL {
        let target = directory.appendingPathComponent(
            "\(profile.uuid).\(profileExtension(for: profile.platform))"
        )
        do {
            try profile.content.write(to: target, options: .atomic)
        } catch {
            throw AppleDeveloperError.fileWriteFailure(path: target.path, underlying: error)
        }
        return target
    }

    static func writeCertificate(_ certificate: Certificate, into directory: URL) throws -> URL {
        let sanitized = sanitize(certificate.displayName)
        let basename = sanitized.isEmpty ? certificate.id : sanitized
        let target = directory.appendingPathComponent("\(basename).cer")
        do {
            try certificate.content.write(to: target, options: .atomic)
        } catch {
            throw AppleDeveloperError.fileWriteFailure(path: target.path, underlying: error)
        }
        return target
    }

    static func profileExtension(for platform: Platform) -> String {
        switch platform {
        case .macOS, .universal:
            return "provisionprofile"
        case .iOS, .services:
            return "mobileprovision"
        }
    }

    static func sanitize(_ name: String) -> String {
        var output = ""
        var lastWasUnderscore = false
        for character in name {
            switch character {
            case "/", "\\", ":":
                if !lastWasUnderscore {
                    output.append("_")
                    lastWasUnderscore = true
                }
            default:
                output.append(character)
                lastWasUnderscore = false
            }
        }
        let trimSet = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "_"))
        return output.trimmingCharacters(in: trimSet)
    }
}
