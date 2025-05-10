// swift-tools-version: 6.0
// Swiftの最小ビルドバージョン

import PackageDescription

let package = Package(
    name: "ScaryCatScreeningKit",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "ScaryCatScreeningKit",
            targets: ["ScaryCatScreeningKit", "OvRScaryCatScreener", "SCSInterface"]
        ),
    ],
    targets: [
        .target(
            name: "SCSInterface",
            dependencies: [],
            path: "Sources/SCSInterface"
        ),
        .target(
            name: "ScaryCatScreeningKit",
            dependencies: ["MultiClassScaryCatScreener", "OvRScaryCatScreener", "SCSInterface"],
            path: "Sources/ScaryCatScreeningKit"
        ),
        .target(
            name: "MultiClassScaryCatScreener",
            dependencies: ["SCSInterface"],
            path: "Sources/MultiClassScaryCatScreener",
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "OvRScaryCatScreener",
            dependencies: ["SCSInterface"],
            path: "Sources/OvRScaryCatScreener",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "ScaryCatScreeningKitTests",
            dependencies: ["ScaryCatScreeningKit", "MultiClassScaryCatScreener", "SCSInterface"],
            path: "Tests/ScaryCatScreenerTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
