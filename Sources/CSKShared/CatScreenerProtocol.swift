import UIKit

/// 個々の分類結果を表す構造体
public struct Classification: Sendable, Hashable {
    public let identifier: String
    public let confidence: Float

    public init(identifier: String, confidence: Float) {
        self.identifier = identifier
        self.confidence = confidence
    }
}

/// スクリーニング結果全体を格納する構造体
public struct ScreeningReport: Sendable {
    /// 閾値を超えた決定的な検出結果（「要確認」の場合）。なければnil。
    public let decisiveDetection: Classification?
    /// 全てのクラスの分類結果リスト。
    public let allClassifications: [Classification]

    public init(decisiveDetection: Classification? = nil, allClassifications: [Classification]) {
        self.decisiveDetection = decisiveDetection
        self.allClassifications = allClassifications
    }
}

/// 猫の画像を分類する機能を提供するプロトコル
public protocol CatScreenerProtocol: Sendable { // Sendable対応
    /// 初期化
    init?()

    /// 画像のスクリーニング（分類）を実行します。
    /// - Parameters:
    ///   - image: スクリーニング対象の画像
    ///   - probabilityThreshold: 特徴を検出したと判断する確率の閾値 (0.0 ~ 1.0)
    /// - Returns: スクリーニング結果 (`ScreeningReport`)。
    /// - Throws: 予測中にエラーが発生した場合、`Error` をスローします。
    func screen(image: UIImage, probabilityThreshold: Float) async throws -> ScreeningReport
}
