// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Chumen",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "ChumenCore", targets: ["ChumenCore"]),
        .executable(name: "Chumen", targets: ["ChumenMacApp"]),
        .executable(name: "chumenctl", targets: ["ChumenCLI"]),
        .executable(name: "ChumenHelper", targets: ["ChumenHelper"])
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/textual", from: "0.1.0"),
        .package(url: "https://github.com/krzyzanowskim/STTextView", from: "2.2.0")
    ],
    targets: [
        .target(
            name: "ChumenCore",
            resources: [
                // Knowledge files intentionally keep directory names because upstream and Chumen
                // docs both contain common filenames like index.md and log.md.
                .copy("Resources")
            ]
        ),
        .executableTarget(
            name: "ChumenMacApp",
            dependencies: [
                "ChumenCore",
                .product(name: "Textual", package: "textual"),
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
