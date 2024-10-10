// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

var package = Package(
    name: "Libsql",
    platforms: [ .iOS(.v12), .macOS(.v10_13) ],
    products: [
        .library(name: "Libsql", targets: ["Libsql"]),
        
        // Examples
        .executable(name: "Query", targets: ["Query"]),
        .executable(name: "Transaction", targets: ["Transaction"]),
        .executable(name: "Vector", targets: ["Vector"]),
    ],
    targets: [
        .target(name: "Libsql", dependencies: ["CLibsql"]),
        .binaryTarget(name: "CLibsql", path: "Sources/CLibsql/CLibsql.xcframework"),
        .testTarget(name: "LibsqlTests", dependencies: ["Libsql"]),
       
        // Examples
        .executableTarget(
            name: "Query",
            dependencies: ["Libsql"],
            path: "Examples/Query"
        ),
        .executableTarget(
            name: "Transaction",
            dependencies: ["Libsql"],
            path: "Examples/Transaction"
        ),
        .executableTarget(
            name: "Vector",
            dependencies: ["Libsql"],
            path: "Examples/Vector"
        ),
    ]
)
