import Foundation

public enum AppleDeveloperError: Error, Sendable {
    case invalidConfiguration(reason: String)
    case providerFailure(underlying: any Error)
    case decodingFailure(field: String, reason: String)
    case missingRelationship(name: String, onResourceID: String)
    case unhydratedRelationship(name: String, missingIDs: [String])
    case resourceNotFound(kind: String, id: String)
    case fileWriteFailure(path: String, underlying: any Error)
}
