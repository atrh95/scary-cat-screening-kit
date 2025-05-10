import CoreML
import UIKit
import Vision
import SCSInterface

public actor MultiClassScaryCatScreener: ScaryCatScreenerProcotol {
    private static let UnifiedModelName = "ScaryCatScreeningML"

    /// スクリーニングモデル
    private let screeningModel: VNCoreMLModel

    /// モデルをロード (失敗時はエラー)
    public init() throws {
        guard let resourceURL = Bundle.module.resourceURL else {
            throw ScaryCatScreenerError.resourceBundleNotFound.asNSError()
        }

        let modelURL = resourceURL.appendingPathComponent("\(MultiClassScaryCatScreener.UnifiedModelName).mlmodelc")

        if !FileManager.default.fileExists(atPath: modelURL.path) {
            throw ScaryCatScreenerError.modelLoadingFailed(originalError: nil).asNSError()
        }

        do {
            let mlModel = try MLModel(contentsOf: modelURL)
            let visionModel = try VNCoreMLModel(for: mlModel)
            screeningModel = visionModel
        } catch {
            throw ScaryCatScreenerError.modelLoadingFailed(originalError: error).asNSError()
        }
    }

    // MARK: - Screening Logic

    /// 画像配列をスクリーニングし、安全な画像のみを元の順序で返す
    /// - Parameters:
    ///   - images: 入力UIImageの配列
    ///   - probabilityThreshold: 信頼度の閾値 (デフォルト0.65)
    ///   - enableLogging: 内部ログをコンソールに出力するかどうか (デフォルトfalse)
    /// - Returns: 安全と判断されたUIImageの配列 (元の順序を保持)
    /// - Throws: Visionリクエスト処理中の致命的なエラー
    public func screen(
        images: [UIImage],
        probabilityThreshold: Float = 0.65,
        enableLogging: Bool = false
    ) async throws -> [UIImage] {
        var processingResults: [(originalImage: UIImage, isSafe: Bool)] = []

        for image in images {
            var isSafeForCurrentImage = true // デフォルトで安全と仮定
            var currentImageAllObservations: [ClassResultTuple] = []
            var currentImageDecisiveDetection: ClassResultTuple?

            guard let cgImage = image.cgImage else {
                if enableLogging {
                    print(
                        "[MultiClassScaryCatScreener] [ERROR] Failed to get CGImage for an image. Marking as not safe and skipping Vision processing for this image."
                    )
                }
                isSafeForCurrentImage = false // CGImageにできないものは安全ではない
                // この画像に対するレポート（空の検出結果）を出力
                let reportForSkippedImage = MultiClassScreeningReport(decisiveDetection: nil, allClassifications: [])
                if enableLogging {
                    reportForSkippedImage.printReport()
                }
                processingResults.append((originalImage: image, isSafe: isSafeForCurrentImage))
                continue
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNCoreMLRequest(model: screeningModel)
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
                throw ScaryCatScreenerError.predictionFailed(originalError: error).asNSError()
            }

            // 各画像に対するレポートを作成し、コンソールに出力
            let reportForCurrentImage = MultiClassScreeningReport(
                decisiveDetection: currentImageDecisiveDetection,
                allClassifications: currentImageAllObservations.sorted { $0.confidence > $1.confidence }
            )
            if enableLogging {
                reportForCurrentImage.printReport()
            }

            if currentImageDecisiveDetection != nil {
                isSafeForCurrentImage = false // 何か検出されたら安全ではない
            }

            processingResults.append((originalImage: image, isSafe: isSafeForCurrentImage))
        }

        // 安全な画像のみを元の順序でフィルタリングして返す
        let safeImages = processingResults.filter(\.isSafe).map(\.originalImage)
        return safeImages
    }
}
