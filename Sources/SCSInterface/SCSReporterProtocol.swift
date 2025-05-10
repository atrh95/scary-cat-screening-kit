import Foundation

/// Classificationタプルの型エイリアス
public typealias ClassResultTuple = (identifier: String, confidence: Float)

/// スクリーニングレポートのインターフェース
public protocol SCSReporterProtocol {
    /// 閾値を超えた決定的な検出結果（「要確認」の場合）。なければnil。
    var decisiveDetection: ClassResultTuple? { get }
    
    /// レポートの内容をコンソールに出力します。
    func printReport()
} 
