import CoreGraphics
import CoreML
import Kingfisher
import Vision

public actor ScaryCatScreener {
    private struct SCSModelContainer: @unchecked Sendable {
        let visionModel: VNCoreMLModel
        let modelFileName: String
        let request: VNCoreMLRequest
    }

    private var ovrModels: [SCSModelContainer] = []
    private let enableLogging: Bool

    /// バンドルのリソースから全ての .mlmodelc ファイルをロードしてスクリーナーを初期化
    /// - Parameter enableLogging: デバッグログの出力を有効にするかどうか（デフォルト: false）
    public init(enableLogging: Bool = false) async throws {
        // まずプロパティを初期化
        self.enableLogging = enableLogging

        // リソースバンドルの取得
        let bundle = Bundle(for: type(of: self))
        guard let resourceURL = bundle.resourceURL else {
            throw ScaryCatScreenerError.resourceBundleNotFound
        }

        // .mlmodelcファイルの検索
        let modelFileURLs = try await findModelFiles(in: resourceURL)
        guard !modelFileURLs.isEmpty else {
            if self.enableLogging {
                print("[ScaryCatScreener] [Error] バンドルのリソース内に.mlmodelcファイルが存在しません")
            }
            throw ScaryCatScreenerError.modelNotFound
        }

        // 環境に応じたログ出力
        if self.enableLogging {
            #if targetEnvironment(simulator)
                print("[ScaryCatScreener] [Info] シミュレータ環境ではCPUのみを使用")
            #else
                print("[ScaryCatScreener] [Info] 実機環境では全計算ユニットを使用")
            #endif
        }

        // モデルのロード
        let loadedModels = try await loadModels(from: modelFileURLs)
        guard !loadedModels.isEmpty else {
            throw ScaryCatScreenerError.modelNotFound
        }

        // 最終的なモデル配列を設定
        ovrModels = loadedModels

        if self.enableLogging {
            print(
                "[ScaryCatScreener] [Info] \(ovrModels.count)個のOvRモデルをロード完了: \(ovrModels.map(\.modelFileName).joined(separator: ", "))"
            )
        }
    }

    /// リソースディレクトリ内の.mlmodelcファイルを検索
    private func findModelFiles(in resourceURL: URL) async throws -> [URL] {
        let fileManager = FileManager.default
        let resourceKeys: [URLResourceKey] = [.nameKey, .isDirectoryKey]

        guard let enumerator = fileManager.enumerator(
            at: resourceURL,
            includingPropertiesForKeys: resourceKeys,
            options: .skipsHiddenFiles
        ) else {
            throw ScaryCatScreenerError.modelLoadingFailed(originalError: ScaryCatScreenerError.modelNotFound)
        }

        var modelFileURLs: [URL] = []
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "mlmodelc" {
            modelFileURLs.append(fileURL)
        }

        return modelFileURLs
    }

    /// モデルファイルからVisionモデルとリクエストを並列にロード
    private func loadModels(from modelFileURLs: [URL]) async throws -> [SCSModelContainer] {
        var collectedContainers: [SCSModelContainer] = []

        try await withThrowingTaskGroup(of: SCSModelContainer.self) { group in
            for url in modelFileURLs {
                group.addTask {
                    try await self.loadModel(from: url)
                }
            }

            // 完了したタスクの結果を収集
            for try await container in group {
                collectedContainers.append(container)
            }
        }

        return collectedContainers
    }

    /// 個別のモデルファイルからVisionモデルとリクエストをロード
    private func loadModel(from url: URL) async throws -> SCSModelContainer {
        // MLModelConfigurationの設定
        let config = MLModelConfiguration()
        #if targetEnvironment(simulator)
            config.computeUnits = .cpuOnly
        #else
            config.computeUnits = .all
        #endif

        // モデルのロードと設定
        let mlModel = try MLModel(contentsOf: url, configuration: config)
        let visionModel = try VNCoreMLModel(for: mlModel)

        // Visionリクエストの設定
        let request = VNCoreMLRequest(model: visionModel)
        #if targetEnvironment(simulator)
            request.usesCPUOnly = true
        #endif
        request.imageCropAndScaleOption = .scaleFit

        return SCSModelContainer(
            visionModel: visionModel,
            modelFileName: url.deletingPathExtension().lastPathComponent,
            request: request
        )
    }

    // MARK: - Public Screening API

    public func screen(
        cgImages: [CGImage],
        probabilityThreshold: Float = 0.85,
        enableLogging: Bool = false
    ) async throws -> SCScreeningResults {
        if enableLogging {
            print("[ScaryCatScreener] [Info] スクリーニング開始: \(cgImages.count)枚の画像")
        }
        
        // 各画像のスクリーニングを直列で実行
        var results: [IndividualScreeningResult] = []
        for (index, image) in cgImages.enumerated() {
            let scaryFeatures = try await screenSingleImage(
                image,
                at: index,
                probabilityThreshold: probabilityThreshold,
                enableLogging: enableLogging
            )
            results.append(IndividualScreeningResult(
                index: index,
                cgImage: image,
                scaryFeatures: scaryFeatures
            ))
        }

        let screeningResults = SCScreeningResults(results: results)
        
        if enableLogging {
            let dangerousCount = results.filter { !$0.scaryFeatures.isEmpty }.count
            let safeCount = results.count - dangerousCount
            print("[ScaryCatScreener] [Info] スクリーニング完了: 安全 \(safeCount)枚 / 危険 \(dangerousCount)枚")
            
            // 危険な画像がある場合のみ詳細を表示
            if dangerousCount > 0 {
                print("\n=== 危険な画像の詳細 ===")
                for result in results where !result.scaryFeatures.isEmpty {
                    print("画像 \(result.index):")
                    for feature in result.scaryFeatures {
                        print("  - \(feature.featureName) (信頼度: \(String(format: "%.2f", feature.confidence)))")
                    }
                }
                print("======================\n")
            }
        }

        return screeningResults
    }

    private func screenSingleImage(
        _ image: CGImage,
        at index: Int,
        probabilityThreshold: Float,
        enableLogging: Bool
    ) async throws -> [DetectedScaryFeature] {
        var scaryFeatures: [DetectedScaryFeature] = []

        try await withThrowingTaskGroup(of: (modelId: String, observations: [DetectedScaryFeature]?).self) { group in
            for container in self.ovrModels {
                group.addTask {
                    do {
                        let handler = VNImageRequestHandler(cgImage: image, options: [:])
                        try handler.perform([container.request])
                        guard let observations = container.request.results as? [VNClassificationObservation] else {
                            if enableLogging {
                                print("[ScaryCatScreener] [Warning] モデル\(container.modelFileName)の結果が不正な形式")
                            }
                            return (container.modelFileName, nil)
                        }
                        let mappedObservations = observations.map { (
                            featureName: $0.identifier,
                            confidence: $0.confidence
                        ) }
                        return (container.modelFileName, mappedObservations)
                    } catch {
                        if enableLogging {
                            print(
                                "[ScaryCatScreener] [Error] モデル \(container.modelFileName) のVisionリクエスト失敗: \(error.localizedDescription)"
                            )
                        }
                        throw ScaryCatScreenerError.predictionFailed(originalError: error)
                    }
                }
            }

            for try await result in group {
                guard let mappedObservations = result.observations else { continue }

                // 各モデルの検出結果から危険な特徴を収集
                for observation in mappedObservations
                    where observation.confidence >= probabilityThreshold && observation.featureName != "Rest"
                {
                    scaryFeatures.append((featureName: observation.featureName, confidence: observation.confidence))
                }
            }
        }

        return scaryFeatures
    }
}
