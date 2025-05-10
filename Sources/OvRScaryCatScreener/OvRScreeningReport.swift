import Foundation
import SCSInterface

/// 個々のモデルによる検出情報を格納する構造体
public struct ModelDetectionInfo: Sendable {
    /// 検出に使用されたモデルの識別子（例: モデルファイル名、または内部的なID）
    public let modelIdentifier: String
    /// 閾値を超えた決定的な検出結果
    public let detection: ClassResultTuple

    public init(modelIdentifier: String, detection: ClassResultTuple) {
        self.modelIdentifier = modelIdentifier
        self.detection = detection
    }
}

/// OvRスクリーニング結果全体を格納する構造体
public struct OvRScreeningReport: Sendable, SCSReporterProtocol {
    /// 画像を「安全でない」と判断する原因となったモデルの検出情報リスト。
    /// リストが空の場合、画像は「安全」と判断されたことを意味します。
    public let flaggingDetections: [ModelDetectionInfo]
    /// (オプション) 全てのモデルの全ての分類結果を保持することも検討可能ですが、
    /// OvRの性質上、問題が検出されたモデルの情報が主に関心の対象となります。
    // public let allModelsAllClassifications: [String: [ClassResultTuple]] // 例: Key=ModelIdentifier（モデル識別子）

    public init(flaggingDetections: [ModelDetectionInfo]) {
        self.flaggingDetections = flaggingDetections
    }

    /// レポートの内容をコンソールに出力します。
    public func printReport() {
        print("--- OvRスクリーニングレポート ---")

        if flaggingDetections.isEmpty {
            print("[結果] 画像は安全と判断されました。")
        } else {
            print("[結果] 画像は以下の検出により安全でないと判断されました:")
            for (index, modelDetection) in flaggingDetections.enumerated() {
                let confidencePercent = String(format: "%.1f%%", modelDetection.detection.confidence * 100)
                print("  \(index + 1). モデル: \(modelDetection.modelIdentifier)")
                print("     クラス名: \(modelDetection.detection.identifier)")
                print("     信頼度: \(confidencePercent)")
            }
        }
        print("--------------------------")
    }
}
