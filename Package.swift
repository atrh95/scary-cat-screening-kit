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
            targets: ["ScaryCatScreeningKit", "OvRScaryCatScreener"]
        ),
    ],
    targets: [
        .target(
            name: "ScaryCatScreeningKit",
            dependencies: ["MultiClassScaryCatScreener", "OvRScaryCatScreener"],
            path: "Sources/ScaryCatScreeningKit"
        ),
        .target(
            name: "MultiClassScaryCatScreener",
            dependencies: [],
            path: "Sources/MultiClassScaryCatScreener",
            resources: [
                .process("Resources/ScaryCatScreeningML.mlmodel"),
            ]
        ),
        .target(
            name: "OvRScaryCatScreener",
            dependencies: [],
            path: "Sources/OvRScaryCatScreener"
        ),
        .testTarget(
            name: "ScaryCatScreeningKitTests",
            dependencies: ["ScaryCatScreeningKit", "MultiClassScaryCatScreener"],
            path: "Tests/ScaryCatScreenerTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
