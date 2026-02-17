// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SSHMan",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "SSHMan",
            path: "Sources"
        )
    ]
)
