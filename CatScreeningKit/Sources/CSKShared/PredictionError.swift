import Foundation

/// 予測時に発生しうるエラー
public enum PredictionError: Error {
    case modelLoadingFailed(String)
    case modelNotLoaded
    case invalidImage
    case processingError(Error)
    case noResults
    case lowConfidence(threshold: Float, actual: Float)
}
