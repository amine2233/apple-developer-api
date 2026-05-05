import Foundation

public enum Platform: String, Sendable, Hashable, CaseIterable {
    case iOS
    case macOS
    case universal
    case services
}

public enum ProfileType: String, Sendable, Hashable, CaseIterable {
    case iOSAppDevelopment
    case iOSAppStore
    case iOSAppAdHoc
    case iOSAppInHouse
    case macAppDevelopment
    case macAppStore
    case macAppDirect
    case tvOSAppDevelopment
    case tvOSAppStore
    case tvOSAppAdHoc
    case tvOSAppInHouse
    case macCatalystAppDevelopment
    case macCatalystAppStore
    case macCatalystAppDirect
}

public enum ProfileState: String, Sendable, Hashable, CaseIterable {
    case active
    case invalid
}

public enum CertificateType: String, Sendable, Hashable, CaseIterable {
    case applePay
    case applePayMerchantIdentity
    case applePayPspIdentity
    case applePayRSA
    case developerIDKext
    case developerIDKextG2
    case developerIDApplication
    case developerIDApplicationG2
    case development
    case distribution
    case identityAccess
    case iOSDevelopment
    case iOSDistribution
    case macAppDistribution
    case macInstallerDistribution
    case macAppDevelopment
    case passTypeID
    case passTypeIDWithNFC
}
