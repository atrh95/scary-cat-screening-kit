import Vision

/// Classificationタプルの型エイリアス
public typealias ClassResultTuple = (identifier: String, confidence: Float)

/// 画像を安全でないと判定する原因となった検出情報
public struct TriggeringDetection: Sendable {
    /// モデル識別子
    public let modelIdentifier: String
    /// 閾値を超え、かつ 'Rest' ではない、画像をフラグする原因となった単一の分類結果
    public let detection: ClassResultTuple

    public init(modelIdentifier: String, detection: ClassResultTuple) {
        self.modelIdentifier = modelIdentifier
        self.detection = detection
    }
}

/// 単一画像に対するスクリーニング操作の出力。
public struct ScreeningOutput: Sendable {
    /// 実行された全てのモデルからの全ての観測結果。
    /// Key: モデル識別子, Value: そのモデルの観測結果リスト。
    public let allModelObservations: [String: [VNClassificationObservation]]

    /// 画像が安全でないとフラグ付けされる原因となった特定の検出結果 (存在する場合)。
    public let flaggingDetection: TriggeringDetection?

    public init(
        allModelObservations: [String: [VNClassificationObservation]],
        flaggingDetection: TriggeringDetection? = nil
    ) {
        self.allModelObservations = allModelObservations
        self.flaggingDetection = flaggingDetection
    }
}
