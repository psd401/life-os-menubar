// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "LifeOSMenubar",
  platforms: [
    .macOS(.v15)
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
  targets: [
    .target(
      name: "LifeOSMenubarCore",
      path: "Sources/LifeOSMenubarCore"
    ),
    .executableTarget(
      name: "LifeOSMenubar",
      dependencies: ["LifeOSMenubarCore"],
      path: "Sources/LifeOSMenubarApp"
    ),
    .testTarget(
      name: "LifeOSMenubarCoreTests",
      dependencies: ["LifeOSMenubarCore"],
      path: "Tests/LifeOSMenubarCoreTests"
    ),
  ]
)
