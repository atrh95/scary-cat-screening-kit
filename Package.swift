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
            dependencies: ["ScaryCatScreener", "CSKShared"]
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
            name: "CSKShared"
        ),
        .testTarget(
            name: "CatScreeningKitTests",
            dependencies: ["CatScreeningKit"]
        ),
    ],
    swiftLanguageVersions: [.v6],
    exclude: ["CatScreeningML.playground"]
)
