import CoreML
import UIKit
import Vision

public actor ScaryCatScreener {

    private static let UnifiedModelName = "ScaryCatScreeningML"

    /// スクリーニングモデル
    private let screeningModel: VNCoreMLModel

    /// モデルをロード (失敗時はエラー)
    public init() throws {
        guard let resourceURL = Bundle.module.resourceURL else {
            print("[ScaryCatScreener] [ERROR] Resource bundle not found.")
            throw ScaryCatScreenerError.resourceBundleNotFound
        }

        let modelURL = resourceURL.appendingPathComponent("\(ScaryCatScreener.UnifiedModelName).mlmodelc")

        if !FileManager.default.fileExists(atPath: modelURL.path) {
            print("[ScaryCatScreener] [ERROR] Model file not found at \(modelURL.path).")
            throw ScaryCatScreenerError.modelLoadingFailed()
        }

        do {
            let mlModel = try MLModel(contentsOf: modelURL)
            let visionModel = try VNCoreMLModel(for: mlModel)
            self.screeningModel = visionModel
        } catch {
            print("[ScaryCatScreener] [ERROR] Failed to load model '\(ScaryCatScreener.UnifiedModelName)': \(error)")
            throw ScaryCatScreenerError.modelLoadingFailed(underlyingError: error)
        }
    }

    // MARK: - Screening Logic

    /// 画像スクリーニング
    /// - Parameters:
    ///   - image: 入力UIImage
    ///   - probabilityThreshold: 信頼度の閾値 (デフォルト0.65)
    /// - Returns: ScreeningReport (結果)
    /// - Throws: 処理または予測エラー
    public func screen(image: UIImage, probabilityThreshold: Float = 0.65) async throws -> ScreeningReport {
        guard let cgImage = image.cgImage else {
            print("[ScaryCatScreener] [ERROR] Failed to get CGImage.")
            throw ScaryCatScreenerError.invalidImage
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNCoreMLRequest(model: self.screeningModel)
        request.usesCPUOnly = true

        var allObservations: [Classification] = []
        var decisiveDetection: Classification? = nil

        do {
            try handler.perform([request])

            if let results = request.results as? [VNClassificationObservation] {
                allObservations = results.map { Classification(identifier: $0.identifier, confidence: $0.confidence) }
                
                decisiveDetection = allObservations.first { classification in
                    classification.identifier.lowercased() != "safe" && classification.confidence >= probabilityThreshold
                }
            } else {
                return ScreeningReport(decisiveDetection: nil, allClassifications: [])
            }
            
            if allObservations.isEmpty {
                return ScreeningReport(decisiveDetection: nil, allClassifications: [])
            }

        } catch {
            print("[ScaryCatScreener] [ERROR] Vision request failed: \(error).")
            throw ScaryCatScreenerError.predictionFailed(underlyingError: error)
        }
        
        let report = ScreeningReport(
            decisiveDetection: decisiveDetection,
            allClassifications: allObservations.sorted { $0.confidence > $1.confidence }
        )

        return report
    }
}
