// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CatScreeningKit",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "CatScreeningKit",
            targets: ["CatScreeningKit"]
        ),
    ],
    targets: [
        .target(
            name: "CatScreeningKit",
            dependencies: ["ScaryCatScreener", "CSKShared"],
            path: "CatScreeningKit/Sources/CatScreeningKit"
        ),
        .target(
            name: "ScaryCatScreener",
            dependencies: ["CSKShared"],
            path: "CatScreeningKit/Sources/Screeners/ScaryCatScreener",
            resources: [
                .process("Resources/ScaryCatScreeningML.mlmodel"),
            ]
        ),
        .target(
            name: "CSKShared",
            path: "CatScreeningKit/Sources/CSKShared"
        ),
        .testTarget(
            name: "CatScreeningKitTests",
            dependencies: ["CatScreeningKit"],
            path: "CatScreeningKit/Tests/ScaryCatScreenerTests"
        ),
    ],
    swiftLanguageVersions: [.v6],
    exclude: ["CatScreeningML.playground"]
)
