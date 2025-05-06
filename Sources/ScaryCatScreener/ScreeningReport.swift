import Foundation

// Classificationタプルの型エイリアス名を変更
public typealias ClassResultTuple = (identifier: String, confidence: Float)

/// スクリーニング結果全体を格納する構造体
public struct ScreeningReport: Sendable {
    /// 閾値を超えた決定的な検出結果（「要確認」の場合）。なければnil。
    public let decisiveDetection: ClassResultTuple?
    /// 全てのクラスの分類結果リスト。
    public let allClassifications: [ClassResultTuple]

    public init(decisiveDetection: ClassResultTuple? = nil, allClassifications: [ClassResultTuple]) {
        self.decisiveDetection = decisiveDetection
        self.allClassifications = allClassifications
    }
} 