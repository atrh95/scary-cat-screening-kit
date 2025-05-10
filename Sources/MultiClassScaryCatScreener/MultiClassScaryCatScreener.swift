import CoreML
import UIKit
import Vision
import SCSInterface

public actor MultiClassScaryCatScreener: ScaryCatScreenerProcotol {
    private static let ModelNamePrefix = "ScaryCatScreeningML_MultiClass"
    private static let ModelNameSuffix = ".mlmodelc"

    /// スクリーニングモデル
    private let multiClassScreeningModel: VNCoreMLModel

    /// モデルをロード (失敗時はエラー)
    public init() throws {
        guard let resourceURL = Bundle.module.resourceURL else {
            throw ScaryCatScreenerError.resourceBundleNotFound.asNSError()
        }

        // Resourcesディレクトリ内のモデルファイルを検索
        let resourcesPath = resourceURL.appendingPathComponent("Resources")
        let fileManager = FileManager.default
        let modelFiles: [String]

        do {
            let contents = try fileManager.contentsOfDirectory(atPath: resourcesPath.path)
            // コンパイル後の.mlmodelcファイルを検索対象とする
            modelFiles = contents.filter { $0.hasPrefix(MultiClassScaryCatScreener.ModelNamePrefix) && $0.hasSuffix(MultiClassScaryCatScreener.ModelNameSuffix) }
        } catch {
            // Resourcesディレクトリが見つからない場合に発生
            throw ScaryCatScreenerError.modelLoadingFailed(originalError: error).asNSError()
        }

        guard modelFiles.count == 1, let modelFileNameWithExtension = modelFiles.first else {
            // エラーメッセージは明確化のため詳細に記述
            let errorDetail = "Resourcesディレクトリ内に、期待されるコンパイル済みモデルファイル（例: \(MultiClassScaryCatScreener.ModelNamePrefix)_vX\(MultiClassScaryCatScreener.ModelNameSuffix)）が1つだけ存在するはずですが、\(modelFiles.count)個見つかりました。"
            throw ScaryCatScreenerError.modelNotFound(details: errorDetail).asNSError()
        }
        
        // モデルファイルのURLを生成
        let modelURL = resourcesPath.appendingPathComponent(modelFileNameWithExtension)

        // 念のためファイルの物理的存在を確認
        if !fileManager.fileExists(atPath: modelURL.path) {
            throw ScaryCatScreenerError.modelNotFound(details: "モデルファイル \(modelFileNameWithExtension) が期待されるパス \(modelURL.path) に見つかりません。").asNSError()
        }

        do {
            let mlModel = try MLModel(contentsOf: modelURL)
            let visionModel = try VNCoreMLModel(for: mlModel)
            multiClassScreeningModel = visionModel
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
                isSafeForCurrentImage = false // CGImageに変換できない場合は安全でないと判断
                // この画像に対するレポート（空の検出結果）を出力
                let reportForSkippedImage = MultiClassScreeningReport(decisiveDetection: nil, allClassifications: [])
                if enableLogging {
                    reportForSkippedImage.printReport()
                }
                processingResults.append((originalImage: image, isSafe: isSafeForCurrentImage))
                continue
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNCoreMLRequest(model: multiClassScreeningModel)
            request.usesCPUOnly = true

            do {
                try handler.perform([request])
                if let results = request.results as? [VNClassificationObservation] {
                    currentImageAllObservations = results.map { (identifier: $0.className, confidence: $0.confidence) }
                    currentImageDecisiveDetection = currentImageAllObservations.first { tuple in
                        tuple.className.lowercased() != "safe" && tuple.confidence >= probabilityThreshold
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
                isSafeForCurrentImage = false // 有害なコンテンツが検出された場合は安全でないと判断
            }

            processingResults.append((originalImage: image, isSafe: isSafeForCurrentImage))
        }

        // 安全な画像のみを元の順序でフィルタリングして返す
        let safeImages = processingResults.filter(\.isSafe).map(\.originalImage)
        return safeImages
    }
}
