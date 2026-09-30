// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "multipeer_bridge",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(
      name: "multipeer-bridge",
      targets: ["multipeer_bridge"]
    )
  ],
  dependencies: [],
  targets: [
    .target(
      name: "multipeer_bridge",
      dependencies: [],
      path: "Classes",
      publicHeadersPath: "include",
      linkerSettings: [
        .linkedFramework("MultipeerConnectivity")
      ]
    )
  ]
)
