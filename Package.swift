// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "OneShot",
    platforms: [
        .macOS(.v26),
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
    swiftLanguageModes: [.v6],
)
