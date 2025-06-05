// swift-tools-version: 6.0
// Swiftの最小ビルドバージョン

import PackageDescription

let package = Package(
    name: "scary-cat-screening-kit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
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
            exclude: ["Info.plist"],
            resources: [
                .copy("OvRModels/ScaryCatScreeningML_OvR_black_and_white_v30.mlmodelc"),
                .copy("OvRModels/ScaryCatScreeningML_OvR_human_hands_detected_v30.mlmodelc"),
                .copy("OvRModels/ScaryCatScreeningML_OvR_mouth_open_v32.mlmodelc"),
                .copy("OvRModels/ScaryCatScreeningML_OvR_sphynx_v30.mlmodelc"),
                .copy("OvOModels/ScaryCatScreeningML_OvO_mouth_open_vs_safe_v1.mlmodelc"),
            ]
        ),
        // ,
        // .testTarget(
        //     name: "ScaryCatScreeningKitTests",
        //     dependencies: ["ScaryCatScreeningKit"],
        //     path: "ScaryCatScreenerTests",
        //     exclude: ["Info.plist"],
        //     resources: [
        //         .process("TestResources")
        //     ]
        // )
    ]
)
