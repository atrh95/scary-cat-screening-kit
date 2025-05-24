import CoreGraphics
import Foundation
import Vision

/// 検出された怖い特徴（クラス名と信頼度のペア）
public typealias DetectedScaryFeature = (featureName: String, confidence: Float)

/// 個別の画像のスクリーニング結果
public struct IndividualScreeningResult {
    /// 画像のインデックス
    public let index: Int
    /// スクリーニング対象の画像
    public let cgImage: CGImage
    /// 検出された怖い特徴の配列
    public let scaryFeatures: [DetectedScaryFeature]

    /// 安全と判断されたかどうか
    public var isSafe: Bool {
        scaryFeatures.isEmpty
    }
}

/// スクリーニング結果
public struct SCScreeningResults: Sendable {
    /// 入力画像と同じ順序での各画像のスクリーニング結果
    public let results: [IndividualScreeningResult]

    /// 安全と判断された画像の配列
    public var safeImages: [CGImage] {
        results.filter(\.isSafe).map(\.cgImage)
    }

    /// 検出された怖い特徴ごとの画像と信頼度のマップ
    public var scaryFeatures: [String: [(image: CGImage, confidence: Float)]] {
        Dictionary(
            grouping: results.filter { !$0.isSafe }.flatMap { result in
                result.scaryFeatures.map { feature in
                    (feature.featureName, (image: result.cgImage, confidence: feature.confidence))
                }
            },
            by: { $0.0 }
        ).mapValues { $0.map { $1 } }
    }

    public init(results: [IndividualScreeningResult]) {
        self.results = results
    }

    /// スクリーニング結果の詳細なレポートを出力
    public func printDetailedReport() {
        print("\n=== スクリーニング結果レポート ===")

        // 各画像の結果
        print("\n各画像のスクリーニング結果:")
        for result in results {
            print("\n画像 \(result.index + 1):")
            if result.isSafe {
                print("  状態: 安全")
            } else {
                print("  状態: 危険")
                for feature in result.scaryFeatures {
                    print("  検出: \(feature.featureName) (信頼度: \(String(format: "%.2f", feature.confidence)))")
                }
            }
        }

        // サマリー
        print("\nサマリー:")
        print("安全な画像: \(safeImages.count)枚")
        print("検出された危険な特徴: \(scaryFeatures.count)種類")

        print("\n==============================\n")
    }
}
