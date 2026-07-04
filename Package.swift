// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Chumen",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ChumenCore", targets: ["ChumenCore"]),
        .executable(name: "Chumen", targets: ["ChumenMacApp"]),
        .executable(name: "chumenctl", targets: ["ChumenCLI"]),
        .executable(name: "ChumenHelper", targets: ["ChumenHelper"])
    ],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/STTextView", from: "2.2.0")
    ],
    targets: [
        .target(name: "ChumenCore"),
        .executableTarget(
            name: "ChumenMacApp",
            dependencies: [
                "ChumenCore",
                .product(name: "STTextView", package: "STTextView")
            ]
        ),
        .executableTarget(
            name: "ChumenCLI",
            dependencies: ["ChumenCore"]
        ),
        .executableTarget(
            name: "ChumenHelper",
            dependencies: ["ChumenCore"]
        ),
        .testTarget(
            name: "ChumenCoreTests",
            dependencies: ["ChumenCore"]
        )
    ]
)
