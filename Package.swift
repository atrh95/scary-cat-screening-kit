// swift-tools-version: 6.0
// Swiftの最小ビルドバージョン

import PackageDescription

let package = Package(
    name: "scary-cat-screening-kit",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "ScaryCatScreeningKit",
            targets: ["ScaryCatScreeningKit"]
        ),
    ],
    targets: [
        .target(
            name: "ScaryCatScreeningKit",
            dependencies: [],
            path: "Sources",
            resources: [
                .process("OvRModels"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
