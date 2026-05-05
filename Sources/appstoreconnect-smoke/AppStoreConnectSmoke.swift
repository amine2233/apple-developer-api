import AppleDeveloperAPI
import Foundation

@main
struct AppStoreConnectSmoke {
    static func main() async {
        do {
            let config = try Config.parse(arguments: CommandLine.arguments)
            try await runPipeline(config: config)
        } catch is HelpRequested {
            print(usageText)
            exit(0)
        } catch let error as UsageError {
            stderr("Error: \(error.message)\n\n")
            stderr(usageText)
            exit(2)
        } catch let error as AppleDeveloperError {
            stderr("AppleDeveloperError: \(format(error))\n")
            exit(1)
        } catch {
            stderr("Unexpected error: \(error)\n")
            exit(1)
        }
    }
}

// MARK: - Config

struct Config {
    let issuerID: String
    let privateKeyID: String
    let privateKey: String
    let bundleIdentifier: String
    let saveTo: String?

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func parse(arguments: [String]) throws -> Config {
        var args = Array(arguments.dropFirst())
        if args.contains("--help") || args.contains("-h") {
            throw HelpRequested()
        }
        if args.isEmpty {
            throw UsageError(message: "missing arguments")
        }

        var flagValues: [String: String] = [:]
        var positionals: [String] = []
        while !args.isEmpty {
            let token = args.removeFirst()
            if token.hasPrefix("--") {
                guard !args.isEmpty else {
                    throw UsageError(message: "flag \(token) requires a value")
                }

                flagValues[token] = args.removeFirst()
            } else {
                positionals.append(token)
            }
        }
        guard let bundleIdentifier = positionals.first, positionals.count == 1 else {
            throw UsageError(message: "expected exactly one positional argument: <bundle-identifier>")
        }

        let env = ProcessInfo.processInfo.environment
        let issuerID = flagValues["--issuer-id"] ?? env["APP_STORE_CONNECT_ISSUER_ID"]
        let keyID = flagValues["--key-id"] ?? env["APP_STORE_CONNECT_KEY_ID"]

        guard let issuerID, !issuerID.isEmpty else {
            throw UsageError(message: "issuer ID missing (set --issuer-id or APP_STORE_CONNECT_ISSUER_ID)")
        }
        guard let keyID, !keyID.isEmpty else {
            throw UsageError(message: "key ID missing (set --key-id or APP_STORE_CONNECT_KEY_ID)")
        }

        let keyPath = flagValues["--private-key-path"] ?? env["APP_STORE_CONNECT_PRIVATE_KEY_PATH"]
        let inlineKey = flagValues["--private-key"] ?? env["APP_STORE_CONNECT_PRIVATE_KEY"]

        let rawKey: String
        if let keyPath, !keyPath.isEmpty {
            do {
                rawKey = try String(contentsOfFile: keyPath, encoding: .utf8)
            } catch {
                throw UsageError(
                    message: "could not read private key at \(keyPath): \(error.localizedDescription)"
                )
            }
        } else if let inlineKey, !inlineKey.isEmpty {
            rawKey = inlineKey
        } else {
            throw UsageError(
                message: "private key missing (set --private-key-path / APP_STORE_CONNECT_PRIVATE_KEY_PATH "
                    + "or --private-key / APP_STORE_CONNECT_PRIVATE_KEY)"
            )
        }

        let privateKey = normalizePrivateKey(rawKey)
        guard !privateKey.isEmpty else {
            throw UsageError(message: "private key is empty after normalization")
        }

        return Config(
            issuerID: issuerID,
            privateKeyID: keyID,
            privateKey: privateKey,
            bundleIdentifier: bundleIdentifier,
            saveTo: flagValues["--save-to"]
        )
    }
}

private func normalizePrivateKey(_ raw: String) -> String {
    raw
        .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
        .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
        .components(separatedBy: .whitespacesAndNewlines)
        .joined()
}

// MARK: - Pipeline

private func runPipeline(config: Config) async throws {
    if let saveTo = config.saveTo {
        try await runExportPipeline(config: config, saveTo: saveTo)
        return
    }

    let api: any AppStoreConnectAPI = try AppleDeveloper.Factory.make(
        issuerID: config.issuerID,
        privateKeyID: config.privateKeyID,
        privateKey: config.privateKey
    )

    print("Fetching profiles for bundle id \(config.bundleIdentifier)…")
    let profiles = try await api.fetchProfiles(forBundleIdentifier: config.bundleIdentifier)
    print("→ \(profiles.count) profile(s):")
    guard let firstProfile = profiles.first else {
        print("\nNo profiles for that bundle id; nothing else to fetch.")
        return
    }

    print("\nFetching details for profile \(firstProfile.id)…")
    let details = try await api.fetchProfileDetails(id: firstProfile.id)
    print("→ Profile:")
    print("    name:           \(details.profile.name)")
    print("    uuid:           \(details.profile.uuid)")
    print("    platform:       \(details.profile.platform.rawValue)")
    print("    content size:   \(details.profile.content.count) bytes")
    print("→ Hydrated certificates: \(details.certificates.count)")
    for cert in details.certificates {
        print("  • \(cert.id)  \(cert.displayName)  (\(cert.certificateType.rawValue))")
    }

    guard let firstCert = details.certificates.first else {
        print("\nNo certificates on that profile; nothing else to fetch.")
        return
    }

    print("\nFetching certificate \(firstCert.id)…")
    let cert = try await api.fetchCertificate(id: firstCert.id)
    print("→ Certificate:")
    print("    name:            \(cert.name)")
    print("    displayName:     \(cert.displayName)")
    print("    serialNumber:    \(cert.serialNumber)")
    print("    certificateType: \(cert.certificateType.rawValue)")
    print("    platform:        \(cert.platform?.rawValue ?? "nil")")
    print("    expirationDate:  \(cert.expirationDate)")
}

private func runExportPipeline(config: Config, saveTo: String) async throws {
    let exporter: any BundleArtifactsExporter = try AppleDeveloper.Factory.makeArtifactExporter(
        issuerID: config.issuerID,
        privateKeyID: config.privateKeyID,
        privateKey: config.privateKey
    )

    print("Exporting artifacts for bundle id \(config.bundleIdentifier) to \(saveTo)…")
    let outputURL = URL(fileURLWithPath: saveTo, isDirectory: true)
    let summary = try await exporter.exportArtifacts(
        forBundleIdentifier: config.bundleIdentifier,
        to: outputURL
    )
    print(
        "→ Wrote \(summary.profileFiles.count) profile(s) to \(summary.profilesDirectory.path) "
            + "and \(summary.certificateFiles.count) certificate(s) to \(summary.certificatesDirectory.path)."
    )
    if !summary.skippedProfileIDs.isEmpty {
        print(
            "→ Skipped \(summary.skippedProfileIDs.count) profile(s) (404 on direct lookup, likely expired): "
                + summary.skippedProfileIDs.joined(separator: ", ")
        )
    }
}

// MARK: - Errors & helpers

struct UsageError: Error {
    let message: String
}

struct HelpRequested: Error {}

private func format(_ error: AppleDeveloperError) -> String {
    switch error {
    case let .invalidConfiguration(reason):
        "invalidConfiguration: \(reason)"
    case let .providerFailure(underlying):
        "providerFailure: \(underlying)"
    case let .decodingFailure(field, reason):
        "decodingFailure(\(field)): \(reason)"
    case let .missingRelationship(name, onResourceID):
        "missingRelationship(\(name)) on resource \(onResourceID)"
    case let .unhydratedRelationship(name, missingIDs):
        "unhydratedRelationship(\(name)) missingIDs=\(missingIDs)"
    case let .resourceNotFound(kind, id):
        "resourceNotFound(\(kind)) id=\(id)"
    case let .fileWriteFailure(path, underlying):
        "fileWriteFailure(\(path)): \(underlying)"
    }
}

private func stderr(_ message: String) {
    FileHandle.standardError.write(Data(message.utf8))
}

private let usageText = """
Usage:
  appstoreconnect-smoke <bundle-identifier> [flags]

Flags (override env vars):
  --issuer-id <id>            APP_STORE_CONNECT_ISSUER_ID
  --key-id <id>               APP_STORE_CONNECT_KEY_ID
  --private-key-path <path>   APP_STORE_CONNECT_PRIVATE_KEY_PATH (preferred)
  --private-key <pem-or-b64>  APP_STORE_CONNECT_PRIVATE_KEY
  --save-to <dir>             Export profiles + certificates as files into <dir>
                              instead of running the print pipeline
  -h, --help                  Show this help

Pipeline (default, when --save-to is not set):
  1. fetchProfiles(forBundleIdentifier: <bundle-identifier>)
  2. fetchProfileDetails(id: <first profile's id>)
  3. fetchCertificate(id: <first hydrated certificate's id>)

Export pipeline (when --save-to <dir> is set):
  Writes <dir>/<bundle-id>/profiles/<uuid>.<mobileprovision|provisionprofile>
  and  <dir>/<bundle-id>/certificates/<displayName>.cer for every profile
  attached to the bundle identifier and each of their certificates.

Exit codes:
  0  Success
  1  Runtime error (AppleDeveloperError or unexpected)
  2  Usage error (missing args, bad flags, unreadable key file)

"""
