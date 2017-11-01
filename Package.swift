// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftMysql",
    products: [
        .library(
            name: "SwiftMysql",
            targets: ["SwiftMysql"])
    ],
    dependencies: [
        .package(url: "https://github.com/noppoMan/ProrsumNet.git", .upToNextMajor(from: "0.1.0"))
    ],
    targets: [
        .target(
            name: "SwiftMysql",
            dependencies: ["ProrsumNet"]),
        .testTarget(
            name: "SwiftMysqlTests",
            dependencies: ["SwiftMysql"]),
    ]
)
