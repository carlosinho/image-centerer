// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ImageCenterer",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .target(
            name: "ImageCentererCore"
        ),
        .executableTarget(
            name: "ImageCenterer",
            dependencies: ["ImageCentererCore"]
        ),
        .executableTarget(
            name: "ImageCentererTestRunner",
            dependencies: ["ImageCentererCore"],
        ),
        .testTarget(
            name: "ImageCentererCoreTests",
            dependencies: ["ImageCentererCore"]
        ),
    ]
)
