import UIKit

/// 猫の画像を分類する機能を提供するプロトコル
public protocol CatScreenerProtocol {
    /// 予測結果として採用する最小信頼度
    var minConfidence: Float { get set }

    /// 画像のスクリーニング（分類）を実行します。
    /// - Parameters:
    ///   - image: スクリーニング対象の画像
    /// - Returns: 予測結果 (ラベルと信頼度) のタプル。
    /// - Throws: 予測中にエラーが発生した場合、`PredictionError` をスローします。
    func screen(image: UIImage) async throws -> (label: String, confidence: Float)
}
