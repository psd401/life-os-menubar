// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "LifeOSMenubar",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .library(
      name: "LifeOSMenubarCore",
      targets: ["LifeOSMenubarCore"]
    ),
    .executable(
      name: "LifeOSMenubar",
      targets: ["LifeOSMenubar"]
    ),
  ],
  dependencies: [
    .package(
      url: "https://github.com/sindresorhus/KeyboardShortcuts",
      exact: "3.1.0"
    ),
    .package(path: "Vendor/NexusKit"),
  ],
  targets: [
    .target(
      name: "LifeOSMenubarCore",
      path: "Sources/LifeOSMenubarCore"
    ),
    .executableTarget(
      name: "LifeOSMenubar",
      dependencies: [
        "LifeOSMenubarCore",
        .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
        .product(name: "NexusKit", package: "NexusKit"),
      ],
      path: "Sources/LifeOSMenubarApp"
    ),
    .testTarget(
      name: "LifeOSMenubarCoreTests",
      dependencies: ["LifeOSMenubarCore"],
      path: "Tests/LifeOSMenubarCoreTests"
    ),
  ]
)
