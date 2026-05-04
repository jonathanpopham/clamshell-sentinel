// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ClamshellSentinel",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ClamshellSentinel", targets: ["ClamshellSentinel"]),
        .executable(name: "ClamshellSentinelChecks", targets: ["ClamshellSentinelChecks"]),
        .library(name: "ClamshellSentinelCore", targets: ["ClamshellSentinelCore"])
    ],
    targets: [
        .target(
            name: "ClamshellSentinelCore"
        ),
        .executableTarget(
            name: "ClamshellSentinel",
            dependencies: ["ClamshellSentinelCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "ClamshellSentinelChecks",
            dependencies: ["ClamshellSentinelCore"]
        )
    ]
)
