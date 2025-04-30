import CoreML
import UIKit
import Vision

/// ScaryCatScreenerモデルをロードし、予測を実行するクラス
public final class ScaryCatScreener: CatPredicting {
    /// 共有インスタンス (初期化に失敗した場合は nil)
    public static let shared: CatPredicting? = ScaryCatScreener()

    private let model: VNCoreMLModel

    /// Core MLモデルをロードするための初期化子 (失敗する可能性あり)
    public init?() {
        let modelName = "ScaryCatScreener"
        // Use Bundle.module to access resources in Swift Packages
        guard let modelURL = Bundle.module.url(forResource: modelName, withExtension: "mlmodelc") else {
            print("Error: Failed to find model '\(modelName).mlmodelc' in Bundle.module")
            // Consider adding logging or using modelLoadingFailed error case if init could throw
            return nil
        }

        // Load the MLModel first
        guard let mlModel = try? MLModel(contentsOf: modelURL) else {
            print("Error: Failed to load MLModel from URL: \(modelURL)")
            return nil
        }

        // Create the VNCoreMLModel from the loaded MLModel
        guard let vnModel = try? VNCoreMLModel(for: mlModel) else {
            print("Error: Failed to create VNCoreMLModel from MLModel")
            return nil
        }
        model = vnModel
        print("ScaryCatScreener initialized successfully with model: \(modelName)")
    }

    /// 画像の予測を実行します。
    /// - Parameters:
    ///   - image: 予測対象の画像
    ///   - minConfidence: 予測結果として採用する最小信頼度
    ///   - completion: 予測結果またはエラーを受け取るクロージャ
    public func predict(
        image: UIImage,
        minConfidence: Float,
        completion: @escaping (Result<(label: String, confidence: Float), PredictionError>) -> Void
    ) {
        // Ensure the image can be converted to CGImage
        guard let cgImage = image.cgImage else {
            completion(.failure(.invalidImage))
            return
        }

        // Create a Vision request using the loaded model
        let request = VNCoreMLRequest(model: model) { request, error in
            // Handle potential errors during the request processing
            if let error {
                completion(.failure(.processingError(error)))
                return
            }

            // Process the results (expecting classifications)
            guard let results = request.results as? [VNClassificationObservation],
                  let topResult = results.first
            else {
                completion(.failure(.noResults))
                return
            }

            // Check if the top result meets the minimum confidence threshold
            if topResult.confidence >= minConfidence {
                completion(.success((label: topResult.identifier, confidence: topResult.confidence)))
            } else {
                completion(.failure(.lowConfidence(threshold: minConfidence, actual: topResult.confidence)))
            }
        }

        // Create an image request handler for the input image
        // Orientation handling might be necessary here for correctness depending on image source
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            // Perform the Vision request
            try handler.perform([request])
        } catch {
            // Handle errors during the request handler execution
            completion(.failure(.processingError(error)))
        }
    }
}
