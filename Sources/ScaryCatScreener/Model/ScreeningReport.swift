import Foundation

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