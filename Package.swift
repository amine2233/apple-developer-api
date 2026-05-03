// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "apple-developer-api",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AppleDeveloperAPI",
            targets: ["AppleDeveloperAPI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/AvdLee/appstoreconnect-swift-sdk.git", .upToNextMajor(from: "4.0.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "AppleDeveloperAPI",
            dependencies: [
                .product(name: "AppStoreConnect_Swift_SDK", package: "appstoreconnect-swift-sdk")
            ]
        ),
        .testTarget(
            name: "AppleDeveloperAPITests",
            dependencies: ["AppleDeveloperAPI"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
