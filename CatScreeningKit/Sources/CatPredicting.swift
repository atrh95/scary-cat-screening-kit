import UIKit

/// 猫の画像を分類する機能を提供するプロトコル
public protocol CatPredicting {
    /// 画像の予測を実行します。
    /// - Parameters:
    ///   - image: 予測対象の画像
    ///   - minConfidence: 予測結果として採用する最小信頼度
    ///   - completion: 予測結果またはエラーを受け取るクロージャ
    func predict(
        image: UIImage,
        minConfidence: Float,
        completion: @escaping (Result<(label: String, confidence: Float), PredictionError>) -> Void
    )
}
