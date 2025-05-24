import CoreGraphics
import CoreML
import UIKit
import Vision

public actor ScaryCatScreener {
    
    private struct SCSModelContainer: @unchecked Sendable {
        let model: VNCoreMLModel
        let modelFileName: String
    }

    private let ovrModels: [SCSModelContainer]
    private let enableLogging: Bool

    /// バンドルのリソースから全ての .mlmodelc ファイルをロードしてスクリーナーを初期化
    /// - Parameter enableLogging: デバッグログの出力を有効にするかどうか（デフォルト: false）
    public init(enableLogging: Bool = false) async throws {
        self.enableLogging = enableLogging
        guard let resourceURL = Bundle.module.resourceURL else {
            throw ScaryCatScreenerError.resourceBundleNotFound
        }

        let fileManager = FileManager.default
        var collectedContainers: [SCSModelContainer] = []

        do {
            let resourceKeys: [URLResourceKey] = [.nameKey, .isDirectoryKey]
            let enumerator = fileManager.enumerator(
                at: resourceURL,
                includingPropertiesForKeys: resourceKeys,
                options: .skipsHiddenFiles
            )

            guard let filePaths = enumerator else {
                throw ScaryCatScreenerError.modelLoadingFailed(originalError: ScaryCatScreenerError.modelNotFound)
            }

            var modelFileURLs: [URL] = []
            for case let fileURL as URL in filePaths where fileURL.pathExtension == "mlmodelc" {
                modelFileURLs.append(fileURL)
            }
            
            if modelFileURLs.isEmpty {
                if enableLogging {
                    print("[ScaryCatScreener] [Error] バンドルのリソース内に.mlmodelcファイルが存在しません")
                }
                throw ScaryCatScreenerError.modelNotFound
            }

            if !modelFileURLs.isEmpty {
                let shouldLog = enableLogging
                try await withThrowingTaskGroup(of: SCSModelContainer.self) { group in
                    for url in modelFileURLs {
                        group.addTask {
                            do {
                                let config = MLModelConfiguration()
                                #if targetEnvironment(simulator)
                                config.computeUnits = .cpuOnly
                                if shouldLog {
                                    print("[ScaryCatScreener] [Debug] シミュレータ環境ではCPUのみを使用")
                                }
                                #else
                                config.computeUnits = .all
                                if shouldLog {
                                    print("[ScaryCatScreener] [Debug] 実機環境では全計算ユニットを使用")
                                }
                                #endif
                                let mlModel = try MLModel(contentsOf: url, configuration: config)
                                let visionModel = try VNCoreMLModel(for: mlModel)
                                return SCSModelContainer(model: visionModel, modelFileName: url.deletingPathExtension().lastPathComponent)
                            } catch {
                                if shouldLog {
                                    print("[ScaryCatScreener] [Error] モデルのロードに失敗: \(error.localizedDescription)")
                                }
                                throw ScaryCatScreenerError.modelLoadingFailed(originalError: error)
                            }
                        }
                    }
                    for try await container in group {
                        collectedContainers.append(container)
                    }
                }
            }
        } catch {
            if error is ScaryCatScreenerError {
                throw error
            } else {
                if enableLogging {
                    print("[ScaryCatScreener] [Error] モデルのロードに失敗: \(error.localizedDescription)")
                }
                throw ScaryCatScreenerError.modelLoadingFailed(originalError: error)
            }
        }

        if collectedContainers.isEmpty {
            throw ScaryCatScreenerError.modelNotFound
        }

        self.ovrModels = collectedContainers
        if enableLogging {
            print("[ScaryCatScreener] [Info] \(self.ovrModels.count)個のOvRモデルをロード完了: \(self.ovrModels.map(\.modelFileName).joined(separator: ", "))")
        }
    }

    // MARK: - Public Screening API
    /// 画像配列をスクリーニングし、安全な画像のみを元の順序で返す
    /// - Parameters:
    ///   - images: 入力UIImageの配列
    ///   - probabilityThreshold: 信頼度の閾値 (デフォルト0.65)
    ///   - enableLogging: 内部ログをコンソールに出力するかどうか (デフォルトfalse)
    /// - Returns: 安全と判断されたUIImageの配列 (元の順序を保持)
    /// - Throws: Visionリクエスト処理中の致命的なエラー or image conversion error
    public func screen(
        images: [UIImage],
        probabilityThreshold: Float = 0.85,
        enableLogging: Bool = false
    ) async throws -> [UIImage] {
        var indexedProcessingResults = [(index: Int, image: UIImage, isSafe: Bool)]()
        indexedProcessingResults.reserveCapacity(images.count)

        for (index, image) in images.enumerated() {
            guard let cgImage = image.cgImage else {
                if enableLogging {
                    let report = ScreeningReport(
                        flaggingDetections: [],
                        imageIndex: index + 1,
                        detailedLogOutputs: [LoggableModelOutput(modelIdentifier: "ImageConversionError", observations: [(className: "Failed to convert UIImage to CGImage", confidence: 0.0)])]
                    )
                    report.printReport()
                }
                throw ScaryCatScreenerError.predictionFailed(originalError: ScaryCatScreenerError.modelNotFound)
            }

            var isSafeForCurrentImage = true
            var currentImageFlaggingDetections: [TriggeringDetection] = []
            var loggableOutputsForReport: [LoggableModelOutput]? = nil

            do {
                // 内部の performScreening メソッドを呼び出す
                let screeningOutput = try await performScreening(on: cgImage, probabilityThreshold: probabilityThreshold)

                if let flaggingDetection = screeningOutput.flaggingDetection {
                    isSafeForCurrentImage = false
                    currentImageFlaggingDetections.append(flaggingDetection)
                }

                if enableLogging {
                    loggableOutputsForReport = screeningOutput.allModelObservations.map { modelId, observations in
                        LoggableModelOutput(
                            modelIdentifier: modelId,
                            observations: observations.map { (className: $0.identifier, confidence: $0.confidence) }
                        )
                    }
                }

            } catch let error as ScaryCatScreenerError {
                print("[ScaryCatScreener] [Error] Screening failed for image at index \(index): \(error.localizedDescription)")
                isSafeForCurrentImage = false
                if enableLogging {
                    let errorDescription = error.asNSError().localizedDescription
                    loggableOutputsForReport = [LoggableModelOutput(modelIdentifier: "ScreeningError", observations: [(className: errorDescription, confidence: 0.0)])]
                }
            } catch {
                print("[ScaryCatScreener] [Error] Unknown screening error for image at index \(index): \(error.localizedDescription)")
                isSafeForCurrentImage = false
                if enableLogging {
                    loggableOutputsForReport = [LoggableModelOutput(modelIdentifier: "UnknownScreeningError", observations: [(className: error.localizedDescription, confidence: 0.0)])]
                }
            }

            if enableLogging {
                let report = ScreeningReport(
                    flaggingDetections: currentImageFlaggingDetections,
                    imageIndex: index + 1,
                    detailedLogOutputs: loggableOutputsForReport
                )
                report.printReport()
            }
            indexedProcessingResults.append((index: index, image: image, isSafe: isSafeForCurrentImage))
        }

        return indexedProcessingResults.sorted(by: { $0.index < $1.index }).filter { $0.isSafe }.map { $0.image }
    }

    // MARK: - Screening Logic
    private func performScreening(on cgImage: CGImage, probabilityThreshold: Float) async throws -> ScreeningOutput {
        var allResultsForImage: [String: [ClassResultTuple]] = [:]
        var identifiedFlaggingDetection: TriggeringDetection? = nil

        try await withThrowingTaskGroup(of: (modelId: String, observations: [ClassResultTuple]?).self) { group in
            for container in self.ovrModels {
                group.addTask {
                    do {
                        let request = VNCoreMLRequest(model: container.model)
                        #if targetEnvironment(simulator)
                        request.usesCPUOnly = true
                        #else
                        request.usesCPUOnly = false
                        #endif
                        request.imageCropAndScaleOption = .scaleFit
                        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                        try handler.perform([request])
                        guard let observations = request.results as? [VNClassificationObservation] else {
                            return (container.modelFileName, nil)
                        }
                        // VNClassificationObservationをClassResultTupleに変換
                        let mappedObservations = observations.map { ClassResultTuple(identifier: $0.identifier, confidence: $0.confidence) }
                        return (container.modelFileName, mappedObservations)
                    } catch {
                        if self.enableLogging {
                            print("[ScaryCatScreener] [Error] モデル \(container.modelFileName) のVisionリクエスト失敗: \(error.localizedDescription)")
                        }
                        throw ScaryCatScreenerError.predictionFailed(originalError: error)
                    }
                }
            }

            for try await result in group {
                guard let mappedObservations = result.observations else { continue }
                allResultsForImage[result.modelId] = mappedObservations

                if identifiedFlaggingDetection == nil {
                    if let problematicObs = mappedObservations.first(where: { $0.confidence >= probabilityThreshold && $0.identifier != "Rest" }) {
                        identifiedFlaggingDetection = TriggeringDetection(
                            modelIdentifier: result.modelId,
                            detection: (identifier: problematicObs.identifier, confidence: problematicObs.confidence)
                        )
                    }
                }
            }
        }
        
        return ScreeningOutput(
            allModelObservations: allResultsForImage,
            flaggingDetection: identifiedFlaggingDetection
        )
    }
}
