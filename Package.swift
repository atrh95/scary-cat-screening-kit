// swift-tools-version: 6.0
// Swiftの最小ビルドバージョン

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
            dependencies: ["ScaryCatScreener"],
            path: "Sources/CatScreeningKit"
        ),
        .target(
            name: "ScaryCatScreener",
            dependencies: [],
            path: "Sources/ScaryCatScreener",
            resources: [
                .process("Resources/ScaryCatScreeningML.mlmodel"),
                .copy("SCARY_CAT_SCREENER.md"), // ドキュメントファイル (リソースとしてコピー)
            ]
        ),
        .testTarget(
            name: "CatScreeningKitTests",
            dependencies: ["CatScreeningKit", "ScaryCatScreener"], // テストターゲットはScaryCatScreenerにも直接依存
            path: "Tests/ScaryCatScreenerTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
