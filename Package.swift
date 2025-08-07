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
            name: "CodeParser",
            targets: ["CodeParser"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-format.git", from: "510.1.0")
    ],
    targets: [
        .target(
            name: "CodeParser",
            dependencies: []
        ),
        .target(name: "CodeParserShowCase",
            dependencies: ["CodeParser"]
        ),
        .testTarget(
            name: "CodeParserTests",
            dependencies: ["CodeParser"]
        ),
        .testTarget(
            name: "CodeParserShowCaseTests",
            dependencies: ["CodeParser", "CodeParserShowCase"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
