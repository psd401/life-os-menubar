// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NexusKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "NexusKit", targets: ["NexusKit"])
    ],
    targets: [
        .target(
            name: "NexusKit",
            resources: [.copy("Fonts")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
