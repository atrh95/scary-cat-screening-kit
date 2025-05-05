import UIKit

/// 猫の画像を分類する機能を提供するプロトコル
public protocol CatScreenerProtocol {
    /// 予測結果として採用する最小信頼度
    var minConfidence: Float { get set }

    /// 画像のスクリーニング（分類）を実行します。
    /// - Parameters:
    ///   - image: スクリーニング対象の画像
    ///   - completion: スクリーニング結果またはエラーを受け取るクロージャ
    func screen(
        image: UIImage,
        completion: @escaping (Result<(label: String, confidence: Float), PredictionError>) -> Void
    )
}
