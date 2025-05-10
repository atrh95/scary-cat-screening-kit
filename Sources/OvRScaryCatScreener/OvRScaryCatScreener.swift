import CoreML
import SCSInterface
import UIKit
import Vision

public actor OvRScaryCatScreener: ScaryCatScreenerProtocol {
    // モデルとその元のファイルURL（識別子用）を格納
    private struct OvRModelContainer: @unchecked Sendable {
        let model: VNCoreMLModel
        let identifier: String
    }

    // NEW: Struct to hold all processing results from a single model for detailed logging
    private struct ModelProcessingOutput: @unchecked Sendable {
        let modelIdentifier: String
        let allObservations: [VNClassificationObservation]
        let flaggingObservation: VNClassificationObservation? // The specific observation that flagged the image, if any
    }

    /// スクリーニングモデルのコレクション
    private let ovrScreeningModelContainers: [OvRModelContainer]

    /// モデルをロード (失敗時はエラー)
    public init() async throws {
        guard let resourceURL = Bundle.module.resourceURL else {
            throw ScaryCatScreenerError.resourceBundleNotFound.asNSError()
        }

        let fileManager = FileManager.default
        var collectedModels: [OvRModelContainer] = []

        do {
            let resourceKeys: [URLResourceKey] = [.nameKey, .isDirectoryKey]
            let enumerator = fileManager.enumerator(
                at: resourceURL,
                includingPropertiesForKeys: resourceKeys,
                options: .skipsHiddenFiles
            )

            guard let filePaths = enumerator else {
                throw ScaryCatScreenerError.modelLoadingFailed(originalError: NSError(
                    domain: "OvRScaryCatScreener",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Resourcesディレクトリ内のファイルの列挙に失敗しました。"]
                )).asNSError()
            }

            var modelFileURLs: [URL] = []
            for case let fileURL as URL in filePaths {
                if fileURL.pathExtension == "mlmodelc" { // コンパイルされたモデルファイル
                    modelFileURLs.append(fileURL)
                }
            }

            if !modelFileURLs.isEmpty {
                try await withThrowingTaskGroup(of: OvRModelContainer.self) { group in
                    for fileURL in modelFileURLs {
                        group.addTask {
                            let mlModel = try MLModel(contentsOf: fileURL)
                            let visionModel = try VNCoreMLModel(for: mlModel)
                            let identifier = fileURL.lastPathComponent
                            return OvRModelContainer(model: visionModel, identifier: identifier)
                        }
                    }

                    for try await modelContainer in group {
                        collectedModels.append(modelContainer)
                    }
                }
            }
        } catch {
            if let scaryError = error as? ScaryCatScreenerError {
                throw scaryError.asNSError()
            } else {
                print("[OvRScaryCatScreener] [エラー] 初期化中のモデルロードプロセスでエラーが発生しました: \(error.localizedDescription)")
                throw ScaryCatScreenerError.modelLoadingFailed(originalError: error).asNSError()
            }
        }

        if collectedModels.isEmpty {
            throw ScaryCatScreenerError.modelNotFound.asNSError()
        }

        ovrScreeningModelContainers = collectedModels
        if !ovrScreeningModelContainers.isEmpty {
            print(
                "[OvRScaryCatScreener] [情報] \(ovrScreeningModelContainers.count)個のOvRモデルのロードに成功しました: \(ovrScreeningModelContainers.map(\.identifier).joined(separator: ", "))"
            )
        }
    }

    // MARK: - スクリーニングロジック

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
        var indexedProcessingResults = [(index: Int, image: UIImage, isSafe: Bool)]()
        indexedProcessingResults.reserveCapacity(images.count)

        for (index, image) in images.enumerated() {
            var isSafeForCurrentImage = true
            var currentImageFlaggingDetections: [ModelDetectionInfo] = []

            guard let cgImage = image.cgImage else {
                if enableLogging {
                    let report = OvRScreeningReport(
                        flaggingDetections: [],
                        restDetection: nil,
                        imageIndex: index + 1,
                        detailedLogOutputs: nil
                    )
                    report.printReport()
                }
                indexedProcessingResults.append((index: index, image: image, isSafe: false))
                continue // Move to the next image
            }

            let modelOutputs: [ModelProcessingOutput] = await withTaskGroup(
                of: ModelProcessingOutput.self, // Changed from ModelDetectionInfo?
                returning: [ModelProcessingOutput].self // Changed from [ModelDetectionInfo?]
            ) { modelTaskGroup in
                for container in self.ovrScreeningModelContainers {
                    modelTaskGroup.addTask {
                        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                        let request = VNCoreMLRequest(model: container.model)
                        request.usesCPUOnly = true
                        request.imageCropAndScaleOption = .scaleFit
                        var allObservationsForCurrentModel: [VNClassificationObservation] = []
                        var specificFlaggingObservation: VNClassificationObservation? = nil

                        do {
                            try handler.perform([request])
                            if let results = request.results as? [VNClassificationObservation] {
                                allObservationsForCurrentModel = results
                                if let problematicObservation = results
                                    .first(where: { $0.confidence >= probabilityThreshold && $0.identifier != "Rest" })
                                {
                                    specificFlaggingObservation = problematicObservation
                                }
                            }
                        } catch {
                            if enableLogging {
                                print(
                                    "[OvRScaryCatScreener] [エラー] モデル\(container.identifier)のVisionリクエストに失敗しました: \(error.localizedDescription)"
                                )
                            }
                            // Still return a ModelProcessingOutput, but with empty observations and no flagging one.
                        }
                        return ModelProcessingOutput(
                            modelIdentifier: container.identifier,
                            allObservations: allObservationsForCurrentModel,
                            flaggingObservation: specificFlaggingObservation
                        )
                    }
                }

                var collectedOutputs: [ModelProcessingOutput] = []
                collectedOutputs.reserveCapacity(self.ovrScreeningModelContainers.count)
                for await output in modelTaskGroup {
                    collectedOutputs.append(output)
                }
                return collectedOutputs
            }

            currentImageFlaggingDetections = [] // Reset for current image
            isSafeForCurrentImage = true // Assume safe until a flagging detection is found

            for output in modelOutputs {
                if let flaggingObs = output.flaggingObservation {
                    isSafeForCurrentImage = false
                    // Assuming ModelDetectionInfo structure as per previous discussions.
                    // This part remains to correctly build the flaggingDetections array for the report.
                    currentImageFlaggingDetections.append(ModelDetectionInfo(
                        modelIdentifier: output.modelIdentifier,
                        detection: (identifier: flaggingObs.identifier, confidence: flaggingObs.confidence)
                    ))
                }
            }

            var bestRestDetection: ClassResultTuple? = nil
            if isSafeForCurrentImage {
                for output in modelOutputs {
                    for observation in output.allObservations {
                        if observation.identifier == "Rest" {
                            if bestRestDetection == nil || observation.confidence > bestRestDetection!.confidence {
                                bestRestDetection = (
                                    identifier: observation.identifier,
                                    confidence: observation.confidence
                                )
                            }
                            break // This model found "Rest", so break the loop
                        }
                    }
                }
            }

            // enableLogging is true only if detailed log outputs are included in the report
            var loggableOutputsForReport: [LoggableModelOutput]? = nil
            if enableLogging, isSafeForCurrentImage { // Detailed log outputs are created only for safe images
                loggableOutputsForReport = modelOutputs.map { processingOutput -> LoggableModelOutput in
                    let observations = processingOutput.allObservations.map { vnObservation -> (String, Float) in
                        return (className: vnObservation.identifier, confidence: vnObservation.confidence)
                    }
                    return LoggableModelOutput(
                        modelIdentifier: processingOutput.modelIdentifier,
                        observations: observations
                    )
                }
            }

            // OvRScaryCatScreener side detailed log outputs are removed (OvRScreeningReport handles them)

            if enableLogging { // Detailed log outputs are included in the report only if enableLogging is true
                let reportForCurrentImage = OvRScreeningReport(
                    flaggingDetections: currentImageFlaggingDetections,
                    restDetection: bestRestDetection,
                    imageIndex: index + 1, // Always pass the index
                    detailedLogOutputs: loggableOutputsForReport // Value is only present if enableLogging is true for
                    // safe images
                )
                reportForCurrentImage.printReport()
            } else if !isSafeForCurrentImage {
                // Even if enableLogging is false, a simple report is output for unsafe images
                let reportForCurrentImage = OvRScreeningReport(
                    flaggingDetections: currentImageFlaggingDetections,
                    restDetection: nil, // Rest information is not needed for unsafe images
                    imageIndex: index + 1, // Index is passed for situation awareness
                    detailedLogOutputs: nil
                )
                reportForCurrentImage.printReport()
            }

            indexedProcessingResults.append((index: index, image: image, isSafe: isSafeForCurrentImage))
        }

        let safeImages = indexedProcessingResults.sorted(by: { $0.index < $1.index }).filter(\.isSafe).map(\.image)
        return safeImages
    }
}
