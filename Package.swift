// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CodeParser",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CodeParserCore",
            targets: ["CodeParserCore"]
        ),
        .library(
            name: "CodeParserCollection",
            targets: ["CodeParserCollection"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-format.git", from: "510.1.0")
    ],
    targets: [
        .target(
            name: "CodeParserCore",
            dependencies: []
        ),
        .target(name: "CodeParserCollection",
            dependencies: ["CodeParserCore"]
        ),
        .testTarget(
            name: "CodeParserCoreTests",
            dependencies: ["CodeParserCore"]
        ),
        .testTarget(
            name: "CodeParserCollectionTests",
            dependencies: ["CodeParserCore", "CodeParserCollection"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
