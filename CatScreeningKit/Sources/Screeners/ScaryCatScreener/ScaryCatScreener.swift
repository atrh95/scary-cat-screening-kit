import CoreML
import UIKit
import Vision
import CSKShared

/// ScaryCatScreenerモデルをロードし、予測を実行するクラス
public final class ScaryCatScreener: CatScreenerProtocol {
    /// 共有インスタンス (初期化に失敗した場合は nil)
    public static let shared: CatScreenerProtocol? = ScaryCatScreener()

    // MARK: - Properties

    private let model: ScaryCatScreeningML?
    private var visionModel: VNCoreMLModel?
    public var minConfidence: Float = 0.7 // Default confidence threshold

    // MARK: - Initialization

    /// Core MLモデルをロードするための初期化子 (失敗する可能性あり)
    public init?() {
        guard let url = Bundle.module.url(forResource: "ScaryCatScreeningML", withExtension: "mlmodelc") else {
            print("Error: Model file not found in bundle.")
            return nil
        }
        do {
            let mlModel = try MLModel(contentsOf: url)
            model = ScaryCatScreeningML(model: mlModel) // Keep the specific model type internally
            visionModel = try VNCoreMLModel(for: mlModel)
            print("ScaryCatPredictor initialized successfully.")
        } catch {
            print("Error initializing model: \(error)")
            return nil
        }
    }

    // MARK: - Prediction

    /// Predicts if the cat in the image is scary or not scary.
    /// - Parameters:
    ///   - image: The input UIImage.
    ///   - completion: The completion handler returning the result.
    public func screen(
        image: UIImage,
        completion: @escaping (Result<(label: String, confidence: Float), PredictionError>) -> Void
    ) {
        // Ensure the image can be converted to CGImage
        guard let cgImage = image.cgImage else {
            completion(.failure(.invalidImage))
            return
        }

        // Ensure the vision model is available
        guard let visionModel else {
            completion(.failure(.modelNotLoaded))
            return
        }

        // Create a Vision request using the loaded model
        let request = VNCoreMLRequest(model: visionModel) { request, error in
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
            if topResult.confidence >= self.minConfidence {
                completion(.success((label: topResult.identifier, confidence: topResult.confidence)))
            } else {
                completion(.failure(.lowConfidence(threshold: self.minConfidence, actual: topResult.confidence)))
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

    // MARK: - Private Helper

    private func processObservations(
        for _: VNRequest,
        error _: Error?,
        completion _: @escaping (Result<(label: String, confidence: Float), PredictionError>) -> Void
    ) {
        // ... rest of the method implementation ...
    }
}
