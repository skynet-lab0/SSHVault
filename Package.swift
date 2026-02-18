// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SSHVault",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "SSHVault",
            path: "Sources"
        )
    ]
)
