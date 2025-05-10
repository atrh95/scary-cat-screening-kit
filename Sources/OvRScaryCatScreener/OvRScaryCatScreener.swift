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
                    print(
                        "[OvRScaryCatScreener] [エラー] CGImageの取得に失敗しました。画像を安全でないと判断し、この画像のVision処理をスキップします。"
                    )
                    let reportForSkippedImage = OvRScreeningReport(flaggingDetections: [])
                    reportForSkippedImage.printReport()
                }
                indexedProcessingResults.append((index: index, image: image, isSafe: false))
                continue // Move to the next image
            }

            let detectionResultsFromModels: [ModelDetectionInfo?] = await withTaskGroup(
                of: ModelDetectionInfo?.self,
                returning: [ModelDetectionInfo?].self
            ) { modelTaskGroup in
                for container in self.ovrScreeningModelContainers {
                    modelTaskGroup.addTask {
                        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                        let request = VNCoreMLRequest(model: container.model)
                        request.usesCPUOnly = true

                        do {
                            try handler.perform([request])
                            if let results = request.results as? [VNClassificationObservation],
                               let problematicObservation = results
                               .first(where: { $0.confidence >= probabilityThreshold })
                            {
                                return ModelDetectionInfo(
                                    modelIdentifier: container.identifier,
                                    detection: (
                                        identifier: problematicObservation.identifier,
                                        confidence: problematicObservation.confidence
                                    )
                                )
                            }
                            return nil
                        } catch {
                            if enableLogging {
                                print(
                                    "[OvRScaryCatScreener] [エラー] モデル\(container.identifier)のVisionリクエストに失敗しました: \(error.localizedDescription)"
                                )
                            }
                            return nil
                        }
                    }
                }

                var collectedDetections: [ModelDetectionInfo?] = []
                collectedDetections.reserveCapacity(self.ovrScreeningModelContainers.count)
                for await detectionResult in modelTaskGroup {
                    collectedDetections.append(detectionResult)
                }
                return collectedDetections
            }

            for detectionInfoOrNil in detectionResultsFromModels {
                if let validDetectionInfo = detectionInfoOrNil {
                    currentImageFlaggingDetections.append(validDetectionInfo)
                    isSafeForCurrentImage = false
                }
            }

            if enableLogging {
                let reportForCurrentImage =
                    OvRScreeningReport(flaggingDetections: currentImageFlaggingDetections)
                reportForCurrentImage.printReport()
            }

            indexedProcessingResults.append((index: index, image: image, isSafe: isSafeForCurrentImage))
        }

        let safeImages = indexedProcessingResults.sorted(by: { $0.index < $1.index }).filter { $0.isSafe }.map { $0.image }
        return safeImages
    }
}
