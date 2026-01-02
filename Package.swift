// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftRest",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "SwiftRest",
            targets: ["SwiftRest"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SwiftRest",
            dependencies: []),
        .testTarget(
            name: "SwiftRestTests",
            dependencies: ["SwiftRest"]),
    ]
)
