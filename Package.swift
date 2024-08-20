// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Libsql",
  products: [
    .library(name: "Libsql", targets: ["Libsql"])
  ],
  targets: [
    .target(
      name: "Libsql",
      dependencies: ["CLibsql"],
      linkerSettings: [
        .unsafeFlags(["-L", "Sources/CLibsql/target/release"])
      ]),
    .systemLibrary(name: "CLibsql"),
    .testTarget(name: "LibsqlTests", dependencies: ["Libsql"]),
  ]
)
