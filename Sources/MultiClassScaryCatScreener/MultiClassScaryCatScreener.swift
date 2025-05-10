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
        let modelFilesPath = resourceURL
        let fileManager = FileManager.default
        let modelFiles: [String]

        do {
            // 指定されたパスのコンテンツを取得
            let contents = try fileManager.contentsOfDirectory(atPath: modelFilesPath.path)
            // コンパイル後の.mlmodelcファイルを検索対象とする
            modelFiles = contents.filter { $0.hasPrefix(MultiClassScaryCatScreener.ModelNamePrefix) && $0.hasSuffix(MultiClassScaryCatScreener.ModelNameSuffix) }
        } catch {
            // ディレクトリのコンテンツ取得に失敗した場合 (例: パスが存在しない、アクセス権限がない)
            // ここでは、モデルロード失敗として扱う
            throw ScaryCatScreenerError.modelLoadingFailed(originalError: error).asNSError()
        }

        guard modelFiles.count == 1, let modelFileNameWithExtension = modelFiles.first else {
            // 期待するモデルファイルが見つからない、または複数見つかった場合
            // 詳細なエラータイプを検討することも可能 (例: .modelNotFound, .multipleModelsFound)
            throw ScaryCatScreenerError.modelNotFound.asNSError()
        }
        
        // モデルファイルの完全なURLを生成
        let modelURL = modelFilesPath.appendingPathComponent(modelFileNameWithExtension)

        // 念のためファイルの物理的存在を確認 (通常はcontentsOfDirectoryで確認済みだが、追加の堅牢性のため)
        if !fileManager.fileExists(atPath: modelURL.path) {
            throw ScaryCatScreenerError.modelNotFound.asNSError()
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
                    currentImageAllObservations = results.map { (identifier: $0.identifier, confidence: $0.confidence) }
                    currentImageDecisiveDetection = currentImageAllObservations.first { tuple in
                        tuple.confidence >= probabilityThreshold
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
