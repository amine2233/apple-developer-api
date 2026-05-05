import Foundation

public struct Certificate: Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let displayName: String
    public let serialNumber: String
    public let certificateType: CertificateType
    public let platform: Platform?
    public let expirationDate: Date
    public let content: Data

    public init(
        id: String,
        name: String,
        displayName: String,
        serialNumber: String,
        certificateType: CertificateType,
        platform: Platform?,
        expirationDate: Date,
        content: Data
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.serialNumber = serialNumber
        self.certificateType = certificateType
        self.platform = platform
        self.expirationDate = expirationDate
        self.content = content
    }
}
