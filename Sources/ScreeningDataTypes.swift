import CoreGraphics
import Foundation
import Vision

/// 検出された特徴（クラス名と信頼度のペア）
public typealias DetectedFeature = (featureName: String, confidence: Float)

/// 個別の画像のスクリーニング結果
public struct IndividualScreeningResult {
    public let index: Int
    public let cgImage: CGImage
    public let detectedFeatures: [DetectedFeature]
    public let probabilityThreshold: Float

    /// イニシャライザ
    /// - Parameters:
    ///   - index: 画像のインデックス
    ///   - cgImage: スクリーニング対象の画像
    ///   - detectedFeatures: 検出された特徴の配列
    ///   - probabilityThreshold: 危険と判断される閾値
    public init(
        index: Int,
        cgImage: CGImage,
        detectedFeatures: [DetectedFeature],
        probabilityThreshold: Float
    ) {
        self.index = index
        self.cgImage = cgImage
        self.detectedFeatures = detectedFeatures
        self.probabilityThreshold = probabilityThreshold
    }

    /// 安全と判断されたかどうか
    public var isSafe: Bool {
        !detectedFeatures.contains { $0.confidence >= probabilityThreshold }
    }

    /// 危険と判断された特徴の配列
    public var scaryFeatures: [DetectedFeature] {
        detectedFeatures.filter { $0.confidence >= probabilityThreshold }
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

    /// スクリーニング結果の詳細なレポートを生成
    public func generateDetailedReport() -> String {
        var report = "\n=== スクリーニング結果レポート ===\n"

        // 各画像の結果（インデックス順）
        for result in results.sorted(by: { $0.index < $1.index }) {
            report += "\n画像 \(result.index + 1):\n"
            if result.isSafe {
                report += "  状態: 安全\n"
                if !result.detectedFeatures.isEmpty {
                    report += "  検出要素:\n"
                    for feature in result.detectedFeatures {
                        report += "    - \(feature.featureName) (信頼度: \(String(format: "%.2f", feature.confidence)))\n"
                    }
                }
            } else {
                report += "  状態: 危険\n"
                
                // 閾値を超えた検出要素
                let aboveThreshold = result.scaryFeatures
                if !aboveThreshold.isEmpty {
                    report += "  閾値を超えた検出要素:\n"
                    for feature in aboveThreshold {
                        report += "    - \(feature.featureName) (信頼度: \(String(format: "%.2f", feature.confidence)))\n"
                    }
                }
                
                // 閾値未満の検出要素
                let belowThreshold = result.detectedFeatures.filter { $0.confidence < result.probabilityThreshold }
                if !belowThreshold.isEmpty {
                    report += "  その他の検出要素:\n"
                    for feature in belowThreshold {
                        report += "    - \(feature.featureName) (信頼度: \(String(format: "%.2f", feature.confidence)))\n"
                    }
                }
            }
        }

        // サマリー
        report += "\nサマリー:\n"
        report += "安全な画像: \(safeImages.count)枚\n"
        report += "検出された危険な特徴: \(scaryFeatures.count)種類\n"

        report += "\n==============================\n"
        return report
    }
}
