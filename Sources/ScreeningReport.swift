import Foundation

/// ログ出力用の詳細なモデル出力情報
public struct LoggableModelOutput: Sendable {
    public let modelIdentifier: String
    public let observations: [(className: String, confidence: Float)]

    public init(modelIdentifier: String, observations: [(className: String, confidence: Float)]) {
        self.modelIdentifier = modelIdentifier
        self.observations = observations
    }
}

/// スクリーニング結果レポート
public struct ScreeningReport: Sendable {
    /// 画像を安全でないと判断させた検出情報のリスト
    public let flaggingDetections: [TriggeringDetection]
    /// (ログ用) 処理された画像のインデックス
    public let imageIndex: Int?
    /// (ログ用) 各モデルの詳細な出力結果
    public let detailedLogOutputs: [LoggableModelOutput]?

    public init(
        flaggingDetections: [TriggeringDetection],
        imageIndex: Int? = nil,
        detailedLogOutputs: [LoggableModelOutput]? = nil
    ) {
        self.flaggingDetections = flaggingDetections
        self.imageIndex = imageIndex
        self.detailedLogOutputs = detailedLogOutputs
    }

    /// レポート内容をコンソールに出力
    public func printReport() {
        if let index = imageIndex {
            print("[ScaryCatScreener] --- [画像 \\(index)] スクリーニングレポート ---")
        } else {
            print("--- スクリーニングレポート ---")
        }

        if flaggingDetections.isEmpty {
            if let detailedOutputs = detailedLogOutputs, !detailedOutputs.isEmpty {
                print("  詳細なモデル出力：")
                for output in detailedOutputs {
                    print("    モデル： \\(output.modelIdentifier)")
                    for observation in output.observations {
                        let confidencePercent = String(format: "%.3f%%", observation.confidence * 100)
                        print("      クラス： \\(observation.className)、信頼度： \\(confidencePercent)")
                    }
                }
                 print("  -----------------------------")
            }
            // Modified final safe result message
            print("[結果] 画像は安全と判断されました。")
            if detailedLogOutputs == nil || detailedLogOutputs?.isEmpty == true {
                print("  詳細な信頼度情報はありません（全てのモデルで閾値超過なし、またはログ無効）。")
            }
        } else {
            print("[結果] 画像は以下の検出により安全でないと判断されました:")
            for (index, modelDetection) in flaggingDetections.enumerated() {
                let confidencePercent = String(format: "%.1f%%", modelDetection.detection.confidence * 100)
                print("  \(index + 1). モデル: \(modelDetection.modelIdentifier)")
                print("     クラス名: \(modelDetection.detection.identifier)")
                print("     信頼度: \(confidencePercent)")
            }
        }
        print("==============================")
    }
}
