// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

var package = Package(
    name: "Libsql",
    platforms: [ .iOS(.v12), .macOS(.v10_13) ],
    products: [
        .library(name: "Libsql", targets: ["Libsql"])
    ],
    targets: [
        .target(name: "Libsql", dependencies: ["CLibsql"]),
        .binaryTarget(name: "CLibsql", path: "Sources/CLibsql/CLibsql.xcframework"),
        .testTarget(name: "LibsqlTests", dependencies: ["Libsql"]),
    ]
)
