// swift-tools-version: 5.9.0
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
        .executable(name: "Batch", targets: ["Batch"]),
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
        .executableTarget(
            name: "Batch",
            dependencies: ["Libsql"],
            path: "Examples/Batch",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "Local",
            dependencies: ["Libsql"],
            path: "Examples/Local",
            exclude: ["README.md", "local.db"]
        ),
        .executableTarget(
            name: "Memory",
            dependencies: ["Libsql"],
            path: "Examples/Memory",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "Remote",
            dependencies: ["Libsql"],
            path: "Examples/Remote",
            exclude: ["README.md", "local.db", "local.db-shm", "local.db-client_wal_index", "local.db-wal"]
        ),
        .executableTarget(
            name: "Sync",
            dependencies: ["Libsql"],
            path: "Examples/Sync",
            exclude: ["README.md", "local.db", "local.db-shm", "local.db-client_wal_index", "local.db-wal"]
        ),
        .executableTarget(
            name: "Transactions",
            dependencies: ["Libsql"],
            path: "Examples/Transactions",
            exclude: ["README.md", "local.db"]
        ),
    ]
)
