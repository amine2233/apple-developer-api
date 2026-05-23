import Foundation

struct BundleArtifactsExporterDefault: BundleArtifactsExporter {
    private let api: any AppStoreConnectAPI

    init(api: any AppStoreConnectAPI) {
        self.api = api
    }

    func exportArtifacts(
        forBundleIdentifier bundleIdentifier: String,
        to outputDirectory: URL,
        platforms: Set<Platform>,
        distributionKinds: Set<DistributionKind>
    ) async throws -> ArtifactExportSummary {
        let bundleDir = outputDirectory.appendingPathComponent(bundleIdentifier, isDirectory: true)
        let profilesDir = bundleDir.appendingPathComponent("profiles", isDirectory: true)
        let certificatesDir = bundleDir.appendingPathComponent("certificates", isDirectory: true)
        try Self.makeDirectory(profilesDir)
        try Self.makeDirectory(certificatesDir)

        let profiles = try await api.fetchProfiles(forBundleIdentifier: bundleIdentifier)

        var profileFiles: [URL] = []
        var certificateFiles: [URL] = []
        var seenCertificateIDs: Set<String> = []
        var skippedProfileIDs: [String] = []

        for profile in profiles {
            guard platforms.contains(profile.platform) else { continue }

            let details: ProfileDetails
            do {
                details = try await api.fetchProfileDetails(id: profile.id)
            } catch let AppleDeveloperError.resourceNotFound(kind, _) where kind == "profile" {
                skippedProfileIDs.append(profile.id)
                continue
            }

            let kinds = Self.classify(certs: details.certificates)
            guard !kinds.isDisjoint(with: distributionKinds) else { continue }

            try profileFiles.append(Self.writeProfile(profile, into: profilesDir))
            for cert in details.certificates where seenCertificateIDs.insert(cert.id).inserted {
                try certificateFiles.append(Self.writeCertificate(cert, into: certificatesDir))
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
        let basename = sanitized.isEmpty ? certificate.id : "\(sanitized) - \(certificate.id)"
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
            "provisionprofile"
        case .iOS, .services:
            "mobileprovision"
        }
    }

    static func classify(certs: [Certificate]) -> Set<DistributionKind> {
        var kinds: Set<DistributionKind> = []
        for cert in certs {
            switch cert.certificateType {
            case .development, .iOSDevelopment, .macAppDevelopment:
                kinds.insert(.development)
            case .distribution, .iOSDistribution,
                 .macAppDistribution, .macInstallerDistribution,
                 .developerIDApplication, .developerIDApplicationG2,
                 .developerIDKext, .developerIDKextG2:
                kinds.insert(.distribution)
            case .applePay, .applePayMerchantIdentity, .applePayPspIdentity, .applePayRSA,
                 .identityAccess, .passTypeID, .passTypeIDWithNFC:
                continue
            }
        }
        if kinds.isEmpty { kinds.insert(.distribution) }
        return kinds
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
