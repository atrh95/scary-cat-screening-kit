import Foundation
import SCSInterface

/// 個々のモデルによる検出情報
public struct ModelDetectionInfo: Sendable {
    /// モデル識別子
    public let modelIdentifier: String
    /// 閾値を超えた検出結果
    public let detection: ClassResultTuple

    public init(modelIdentifier: String, detection: ClassResultTuple) {
        self.modelIdentifier = modelIdentifier
        self.detection = detection
    }
}

/// ログ出力用の詳細なモデル出力情報
public struct LoggableModelOutput: Sendable {
    public let modelIdentifier: String
    public let observations: [(className: String, confidence: Float)]

    public init(modelIdentifier: String, observations: [(className: String, confidence: Float)]) {
        self.modelIdentifier = modelIdentifier
        self.observations = observations
    }
}

/// OvRスクリーニング結果レポート
public struct OvRScreeningReport: Sendable, SCSReporterProtocol {
    /// 画像を安全でないと判断させた検出情報のリスト
    public let flaggingDetections: [ModelDetectionInfo]
    /// 画像が安全と判断された場合の主要な検出情報（例：「Rest」クラス）
    public let restDetection: ClassResultTuple?
    /// (ログ用) 処理された画像のインデックス
    public let imageIndex: Int?
    /// (ログ用) 各モデルの詳細な出力結果
    public let detailedLogOutputs: [LoggableModelOutput]?

    public init(
        flaggingDetections: [ModelDetectionInfo],
        restDetection: ClassResultTuple? = nil,
        imageIndex: Int? = nil,
        detailedLogOutputs: [LoggableModelOutput]? = nil
    ) {
        self.flaggingDetections = flaggingDetections
        self.restDetection = restDetection
        self.imageIndex = imageIndex
        self.detailedLogOutputs = detailedLogOutputs
    }

    /// レポート内容をコンソールに出力
    public func printReport() {
        if let index = imageIndex {
            print("[OvRScaryCatScreener] --- [画像 \(index)] スクリーニングレポート ---")
        } else {
            print("--- OvRスクリーニングレポート ---")
        }

        if flaggingDetections.isEmpty {
            // 安全な場合の詳細ログ出力 (detailedLogOutputs があれば)
            if let detailedOutputs = detailedLogOutputs {
                print("  詳細なモデル出力：")
                for output in detailedOutputs {
                    print("    モデル： \(output.modelIdentifier)")
                    for observation in output.observations {
                        let confidencePercent = String(format: "%.3f%%", observation.confidence * 100)
                        print("      クラス： \(observation.className)、信頼度： \(confidencePercent)")
                    }
                }
                // 最適なRest信頼度の情報をここに移動
                if let restInfo = restDetection {
                     let confidencePercent = String(format: "%.3f%%", restInfo.confidence * 100)
                     print("  レポート用に選択された最適な 'Rest' 信頼度： \(confidencePercent) （クラス： '\(restInfo.identifier)'）")
                } else {
                     print("  レポート用に選択された包括的な 'Rest' 分類はありません（見つからなかったか、ロジックが変更されました）。")
                }
                print("  -----------------------------") // 詳細ログと最終結果の区切り
            }

            // 最終的な安全判定結果
            if let restInfo = restDetection {
                let confidencePercent = String(format: "%.1f%%", restInfo.confidence * 100) // 通常の信頼度は%.1fで表示
                print("[結果] 画像は安全（クラス: \(restInfo.identifier)）と判断されました。")
                print("  信頼度: \(confidencePercent)")
            } else {
                print("[結果] 画像は安全と判断されました。詳細な信頼度情報はありません（全てのモデルで閾値超過なし）。")
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
