import CoreML
import UIKit
import Vision

// Classificationタプルの型エイリアス (ScreeningReport.swiftで定義済みなのでここでは不要)
// public typealias ClassificationTuple = (identifier: String, confidence: Float)

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

    /// 画像配列をスクリーニングし、安全な画像のみを元の順序で返す
    /// - Parameters:
    ///   - images: 入力UIImageの配列
    ///   - probabilityThreshold: 信頼度の閾値 (デフォルト0.65)
    /// - Returns: 安全と判断されたUIImageの配列 (元の順序を保持)
    /// - Throws: Visionリクエスト処理中の致命的なエラー
    public func screen(images: [UIImage], probabilityThreshold: Float = 0.65) async throws -> [UIImage] {
        var processingResults: [(originalImage: UIImage, isSafe: Bool)] = []

        for image in images {
            var isSafeForCurrentImage = true // デフォルトで安全と仮定
            var currentImageAllObservations: [ClassResultTuple] = []
            var currentImageDecisiveDetection: ClassResultTuple? = nil

            guard let cgImage = image.cgImage else {
                print("[ScaryCatScreener] [ERROR] Failed to get CGImage for an image. Marking as not safe and skipping Vision processing for this image.")
                isSafeForCurrentImage = false // CGImageにできないものは安全ではない
                // この画像に対するレポート（空の検出結果）を出力
                let reportForSkippedImage = ScreeningReport(decisiveDetection: nil, allClassifications: [])
                reportForSkippedImage.printReport()
                processingResults.append((originalImage: image, isSafe: isSafeForCurrentImage))
                continue // 次の画像の処理へ
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNCoreMLRequest(model: self.screeningModel)
            request.usesCPUOnly = true

            do {
                try handler.perform([request])
                if let results = request.results as? [VNClassificationObservation] {
                    currentImageAllObservations = results.map { (identifier: $0.identifier, confidence: $0.confidence) }
                    currentImageDecisiveDetection = currentImageAllObservations.first { tuple in
                        tuple.identifier.lowercased() != "safe" && tuple.confidence >= probabilityThreshold
                    }
                }
                // VNClassificationObservationへのキャスト失敗や結果が空の場合、decisiveDetectionはnilのまま
            } catch {
                print("[ScaryCatScreener] [ERROR] Vision request failed for an image: \(error). This error will propagate.")
                // Visionリクエスト失敗はメソッド全体のエラーとする
                throw ScaryCatScreenerError.predictionFailed(underlyingError: error)
            }

            // 各画像に対するレポートを作成し、コンソールに出力
            let reportForCurrentImage = ScreeningReport(
                decisiveDetection: currentImageDecisiveDetection,
                allClassifications: currentImageAllObservations.sorted { $0.confidence > $1.confidence }
            )
            reportForCurrentImage.printReport()

            if currentImageDecisiveDetection != nil {
                isSafeForCurrentImage = false // 何か検出されたら安全ではない
            }
            
            processingResults.append((originalImage: image, isSafe: isSafeForCurrentImage))
        }

        // 安全な画像のみを元の順序でフィルタリングして返す
        let safeImages = processingResults.filter { $0.isSafe }.map { $0.originalImage }
        return safeImages
    }
}
