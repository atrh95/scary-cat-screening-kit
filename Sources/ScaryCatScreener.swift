import CoreGraphics
import CoreML
import UIKit
import Vision

public actor ScaryCatScreener {
    
    private struct OvRModelContainer: @unchecked Sendable {
        var model: VNCoreMLModel
        var identifier: String // モデルファイル名
    }

    private let ovrModels: [OvRModelContainer]

    /// バンドルのリソースから全ての .mlmodelc ファイルをロードしてスクリーナーを初期化します。
    public init() async throws {
        guard let resourceURL = Bundle.module.resourceURL else {
            throw ScaryCatScreenerError.resourceBundleNotFound
        }

        let fileManager = FileManager.default
        var collectedContainers: [OvRModelContainer] = []

        do {
            let resourceKeys: [URLResourceKey] = [.nameKey, .isDirectoryKey]
            let enumerator = fileManager.enumerator(
                at: resourceURL,
                includingPropertiesForKeys: resourceKeys,
                options: .skipsHiddenFiles
            )

            guard let filePaths = enumerator else {
                throw ScaryCatScreenerError.modelLoadingFailed(originalError: NSError(
                    domain: "ScaryCatScreener.Init",
                    code: 1001,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to enumerate files in resource directory."]
                ))
            }

            var modelFileURLs: [URL] = []
            for case let fileURL as URL in filePaths where fileURL.pathExtension == "mlmodelc" {
                // OvRModels ディレクトリ内を参照していることを確認
                if fileURL.path.contains("/OvRModels/") {
                    modelFileURLs.append(fileURL)
                }
            }
            
            if modelFileURLs.isEmpty {
                 print("[ScaryCatScreener] [Warning] No .mlmodelc files found in the OvRModels directory within the bundle\'s resources.")
            }


            if !modelFileURLs.isEmpty {
                try await withThrowingTaskGroup(of: OvRModelContainer.self) { group in
                    for url in modelFileURLs {
                        group.addTask {
                            let mlModel = try MLModel(contentsOf: url)
                            let visionModel = try VNCoreMLModel(for: mlModel)
                            return OvRModelContainer(model: visionModel, identifier: url.deletingPathExtension().lastPathComponent) // .mlmodelc を除いた名前を取得
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
                print("[ScaryCatScreener] [Error] Model loading process failed: (error.localizedDescription)")
                throw ScaryCatScreenerError.modelLoadingFailed(originalError: error)
            }
        }

        if collectedContainers.isEmpty {
            throw ScaryCatScreenerError.modelNotFound // モデルが正常にロードされませんでした
        }

        self.ovrModels = collectedContainers
        print("[ScaryCatScreener] [Info] Successfully loaded (self.ovrModels.count) OvR models: (self.ovrModels.map(.identifier).joined(separator: ", "))")
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
                        detailedLogOutputs: [LoggableModelOutput(modelIdentifier: "ImageConversionError", observations: [(className: "N/A", confidence: 0.0)])]
                    )
                    report.printReport()
                }
                indexedProcessingResults.append((index: index, image: image, isSafe: false))
                continue
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
                print("[ScaryCatScreener] [Error] Screening failed for image at index (index): (error.localizedDescription)")
                isSafeForCurrentImage = false
                 if enableLogging {
                    let errorDescription = error.asNSError().localizedDescription
                    loggableOutputsForReport = [LoggableModelOutput(modelIdentifier: "ScreeningError", observations: [(className: errorDescription, confidence: 0.0)])]
                }
            } catch { // performScreening からのその他のエラーをキャッチ
                print("[ScaryCatScreener] [Error] Unknown screening error for image at index (index): (error.localizedDescription)")
                isSafeForCurrentImage = false
                 if enableLogging {
                     loggableOutputsForReport = [LoggableModelOutput(modelIdentifier: "UnknownScreeningError", observations: [(className: error.localizedDescription, confidence: 0.0)])]
                 }
            }

            if enableLogging || !isSafeForCurrentImage {
                let report = ScreeningReport(
                    flaggingDetections: currentImageFlaggingDetections,
                    imageIndex: index + 1,
                    detailedLogOutputs: loggableOutputsForReport
                )
                report.printReport()
            }
            indexedProcessingResults.append((index: index, image: image, isSafe: isSafeForCurrentImage))
        }

        return indexedProcessingResults.sorted(by: { $0.index < $1.index }).filter(.isSafe).map(.image)
    }

    // MARK: - Screening Logic
    private func performScreening(on cgImage: CGImage, probabilityThreshold: Float) async throws -> ScreeningOutput {
        var allResultsForImage: [String: [VNClassificationObservation]] = [:]
        var identifiedFlaggingDetection: TriggeringDetection? = nil

        await withTaskGroup(of: (modelId: String, observations: [VNClassificationObservation]?).self) { group in
            for container in self.ovrModels {
                group.addTask {
                    let request = VNCoreMLRequest(model: container.model)
                    request.usesCPUOnly = true 
                    request.imageCropAndScaleOption = .scaleFit
                    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                    do {
                        try handler.perform([request])
                        guard let observations = request.results as? [VNClassificationObservation] else {
                            return (container.identifier, nil)
                        }
                        return (container.identifier, observations)
                    } catch {
                        print("[ScaryCatScreener] [Error] Vision request failed for model (container.identifier): (error.localizedDescription)")
                        return (container.identifier, nil)
                    }
                }
            }

            for await result in group {
                guard let observations = result.observations else { continue }
                allResultsForImage[result.modelId] = observations

                if identifiedFlaggingDetection == nil {
                    if let problematicObs = observations.first(where: { $0.confidence >= probabilityThreshold && $0.identifier != "Rest" }) {
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
