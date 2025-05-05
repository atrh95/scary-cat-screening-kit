// swift-tools-version: 6.0
// The swift-tools-version は、このパッケージのビルドに必要な Swift の最小バージョンを宣言

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
            path: "Sources/CatScreeningKit"
        ),
        .target(
            name: "ScaryCatScreener",
            dependencies: ["CSKShared"],
            path: "Sources/ScaryCatScreener"
        ),
        .target(
            name: "CSKShared",
            path: "Sources/CSKShared"
        ),
        .testTarget(
            name: "CatScreeningKitTests",
            dependencies: ["CatScreeningKit"],
            path: "Tests/ScaryCatScreenerTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
