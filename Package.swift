// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Macmontor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Macmontor", targets: ["Macmontor"])
    ],
    targets: [
        .executableTarget(
            name: "Macmontor",
            path: "Sources/Macmontor"
        )
    ]
)
