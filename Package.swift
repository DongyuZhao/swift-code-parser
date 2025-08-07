// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CodeParser",
    platforms: [
        .iOS(.v16),      // iOS 16 and 17 (最近两个大版本)
        .macOS(.v13)     // macOS 13 and 14 (最近两个大版本)
    ],
    products: [
        .library(
            name: "CodeParser",
            targets: ["CodeParser"]
        ),
        .executable(
            name: "CodeParserShowCase",
            targets: ["CodeParserShowCase"]
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
        .executableTarget(name: "CodeParserShowCase",
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
