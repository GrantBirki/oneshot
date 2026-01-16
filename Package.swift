// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "OneShot",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "OneShot",
            targets: ["OneShot"],
        ),
    ],
    targets: [
        .executableTarget(
            name: "OneShot",
            path: "Sources",
            resources: [
                .process("Resources"),
            ],
        ),
        .testTarget(
            name: "OneShotTests",
            dependencies: ["OneShot"],
            path: "Tests",
        ),
    ],
)
