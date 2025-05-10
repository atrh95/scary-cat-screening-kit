import Foundation

/// Classificationタプルの型エイリアス
public typealias ClassResultTuple = (identifier: String, confidence: Float)

public protocol SCSReporterProtocol {
    func printReport()
}
