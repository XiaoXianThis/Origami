// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Origami",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Origami",
            path: "Sources/Origami"
        )
    ]
)
