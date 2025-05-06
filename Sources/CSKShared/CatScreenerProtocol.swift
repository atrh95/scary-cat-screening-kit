import UIKit

/// 猫の画像を分類する機能を提供するプロトコル
public protocol CatScreenerProtocol {
    /// 画像のスクリーニング（分類）を実行します。
    /// - Parameters:
    ///   - image: スクリーニング対象の画像
    ///   - probabilityThreshold: 特徴を検出したと判断する確率の閾値 (0.0 ~ 1.0)
    /// - Returns: 判定結果 ("Safe" または "Not Safe")。
    /// - Throws: 予測中にエラーが発生した場合、`Error` をスローします。
    func screen(image: UIImage, probabilityThreshold: Float) async throws -> (category: String, confidence: Float)?
}
