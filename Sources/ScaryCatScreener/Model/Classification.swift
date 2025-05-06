import Foundation

/// 個々の分類結果を表す構造体
public struct Classification: Sendable, Hashable {
    public let identifier: String
    public let confidence: Float

    public init(identifier: String, confidence: Float) {
        self.identifier = identifier
        self.confidence = confidence
    }
} 