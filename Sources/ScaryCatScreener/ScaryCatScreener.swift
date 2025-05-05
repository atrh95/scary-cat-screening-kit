import CoreML
import CSKShared
import UIKit
import Vision

/// ScaryCatScreenerモデルをロードし、予測を実行するクラス
public final class ScaryCatScreener: CatScreenerProtocol {
    private let model: ScaryCatScreeningML?
    private var visionModel: VNCoreMLModel?
    public var minConfidence: Float = 0.7

    /// Core MLモデルをロードするための初期化子 (失敗する可能性あり)
    public init?() {
        guard let url = Bundle.module.url(forResource: "ScaryCatScreeningML", withExtension: "mlmodelc") else {
            print("Error: Model file not found in bundle.")
            return nil
        }
        do {
            let mlModel = try MLModel(contentsOf: url)
            model = ScaryCatScreeningML(model: mlModel)
            visionModel = try VNCoreMLModel(for: mlModel)
            print("ScaryCatScreener initialized successfully.")
        } catch {
            print("Error initializing model: \(error)")
            return nil
        }
    }

    // MARK: - Prediction

    /// 画像内の猫が怖いか怖くないかを予測します。
    /// - Parameters:
    ///   - image: 入力UIImage。
    /// - Returns: 予測結果 (ラベルと信頼度) のタプル。
    /// - Throws: 予測中にエラーが発生した場合、`PredictionError` をスローします。
    public func screen(image: UIImage) async throws -> (label: String, confidence: Float) {
        guard let cgImage = image.cgImage else {
            throw PredictionError.invalidImage
        }

        guard let visionModel else {
            throw PredictionError.modelNotLoaded
        }

        return try await withCheckedThrowingContinuation { continuation in
            // resumeが一度だけ呼ばれるようにするためのフラグとヘルパー
            var resumed = false
            // 戻り値の型に合わせてタプルの型を (label: String, confidence: Float) に修正
            let resumeOnce: (Result<(label: String, confidence: Float), Error>) -> Void = { result in
                guard !resumed else { return }
                resumed = true
                continuation.resume(with: result)
            }

            let request = VNCoreMLRequest(model: visionModel) { request, error in
                print("DEBUG: VNCoreMLRequest completion handler called.")
                if let error {
                    print("DEBUG: VNCoreMLRequest completion error: \(error)")
                    // エラー発生時は resumeOnce を介して failure を返す
                    resumeOnce(.failure(PredictionError.processingError(error)))
                    return
                }

                guard let results = request.results as? [VNClassificationObservation],
                      let topResult = results.first
                else {
                    print("DEBUG: VNCoreMLRequest no results.")
                    // 結果がない場合も resumeOnce を介して failure を返す
                    resumeOnce(.failure(PredictionError.noResults))
                    return
                }

                if topResult.confidence >= self.minConfidence {
                    print("DEBUG: VNCoreMLRequest success: \(topResult.identifier) - \(topResult.confidence)")
                    // 成功時は resumeOnce を介して success を返す
                    resumeOnce(.success((label: topResult.identifier, confidence: topResult.confidence)))
                } else {
                    print("DEBUG: VNCoreMLRequest low confidence: \(topResult.confidence) < \(self.minConfidence)")
                    // 信頼度が低い場合も resumeOnce を介して failure を返す
                    resumeOnce(.failure(PredictionError.lowConfidence(
                        threshold: self.minConfidence,
                        actual: topResult.confidence
                    )))
                }
            }
            request.usesCPUOnly = true // デバッグ用にCPU推論を強制 (後で必要に応じて削除)
            print("DEBUG: VNCoreMLRequest created. usesCPUOnly=\(request.usesCPUOnly)")

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            print("DEBUG: VNImageRequestHandler created.")
            do {
                print("DEBUG: Calling handler.perform...")
                try handler.perform([request])
                print("DEBUG: handler.perform completed without throwing.")
                // perform が成功した場合、resume は完了ハンドラに任せる
            } catch {
                print("DEBUG: handler.perform threw error: \(error)")
                // perform 自体がエラーを投げた場合、resumeOnce を介して failure を返す
                resumeOnce(.failure(PredictionError.processingError(error)))
            }
        }
    }
}
