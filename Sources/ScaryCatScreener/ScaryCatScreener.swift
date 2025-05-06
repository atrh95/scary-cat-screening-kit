import CoreML
import CSKShared
import UIKit
import Vision

/// Wrapper to mark VNCoreMLModel as Sendable, assuming concurrent request creation is safe.
private struct SendableVNCoreMLModel: @unchecked Sendable {
    let model: VNCoreMLModel
}

/// The main model identifier (without .mlmodelc extension)
private let UnifiedModelName = "ScaryCatScreeningML"

/// Loads a single 4-class Core ML classification model (ScaryCatScreeningML.mlmodel)
/// and determines if an image needs manual review.
/// An image needs review if *any* of the model's output classes
/// ('sphynx', 'black_and_white', 'human_hands_detected', 'mouth_open')
/// has a confidence above a specified threshold.
public final class ScaryCatScreener: CatScreenerProtocol {

    /// Error domain for ScaryCatScreener errors.
    public static let errorDomain = "com.akitorahayashi.ScaryCatScreener.ErrorDomain"

    /// Error codes for ScaryCatScreener operations.
    private enum ErrorCode: Int {
        case resourceBundleNotFound = 1
        // case noModelsFoundInBundle = 2 // Less relevant with a single expected model
        case modelLoadingFailed = 3
        case invalidImage = 4
        case predictionFailed = 5
        case noModelLoaded = 6 // Instance has no model ready (renamed from noModelsLoaded)
    }

    /// The single, unified screening model.
    private let screeningModel: SendableVNCoreMLModel?

    /// Initializes the screener by loading the required `ScaryCatScreeningML.mlmodel` from the bundle's resources.
    /// Returns `nil` if the resource bundle cannot be found or if the model fails to load.
    public init?() {
        guard let resourceURL = Bundle.module.resourceURL else {
            print("[ScaryCatScreener] Error: Could not get resource bundle URL from Bundle.module.")
            self.screeningModel = nil
            return nil
        }

        print("[ScaryCatScreener] Searching for model '\(UnifiedModelName).mlmodelc' in resource bundle: \(resourceURL.path)")

        // Construct the full URL to the compiled model file.
        let modelURL = resourceURL.appendingPathComponent("\(UnifiedModelName).mlmodelc")

        if !FileManager.default.fileExists(atPath: modelURL.path) {
            print("[ScaryCatScreener] Error: Model file '\(UnifiedModelName).mlmodelc' not found at \(modelURL.path).")
            self.screeningModel = nil
            return nil
        }

        do {
            let mlModel = try MLModel(contentsOf: modelURL)
            let visionModel = try VNCoreMLModel(for: mlModel)
            self.screeningModel = SendableVNCoreMLModel(model: visionModel)
            print("[ScaryCatScreener] Successfully loaded model '\(UnifiedModelName)'.")
        } catch {
            print("[ScaryCatScreener] Error loading model '\(UnifiedModelName)' from \(modelURL.path): \(error)")
            self.screeningModel = nil
            return nil
        }
    }

    // MARK: - Screening Logic

    /// Determines if an image triggers a "Not Safe" condition based on the 4-class model.
    /// The model (`ScaryCatScreeningML.mlmodel`) handles its own preprocessing (resize, normalization).
    /// - Parameters:
    ///   - image: The input `UIImage` to screen.
    ///   - probabilityThreshold: The confidence threshold (0.0 to 1.0). If any class confidence
    ///                           exceeds this, that feature is considered detected ("Not Safe"). Defaults to 0.8.
    /// - Returns: A tuple `(category: String, confidence: Float)` containing the class name and confidence
    ///            if any class exceeds the threshold. Returns `nil` if all classes are below the threshold ("Safe").
    /// - Throws: An `Error` if the image cannot be processed or if a prediction error occurs.
    public func screen(image: UIImage, probabilityThreshold: Float = 0.65) async throws -> ScreeningReport {
        let screeningID = UUID().uuidString.prefix(8) // Short unique ID for this screening run
        print("\n--- [ScaryCatScreener] Starting image screening (ID: \(screeningID)) with '\(UnifiedModelName)' ---")

        guard let modelToUse = self.screeningModel else {
            print("[ScaryCatScreener ID: \(screeningID)] Error: Model '\(UnifiedModelName)' not loaded.")
            throw NSError(domain: Self.errorDomain,
                          code: ErrorCode.noModelLoaded.rawValue,
                          userInfo: [NSLocalizedDescriptionKey: "ScaryCatScreener is not initialized with a model."])
        }

        guard let cgImage = image.cgImage else {
            print("[ScaryCatScreener ID: \(screeningID)] Error: Failed to get CGImage from UIImage.")
            throw NSError(domain: Self.errorDomain,
                          code: ErrorCode.invalidImage.rawValue,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage from input UIImage."])
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        print("[ScaryCatScreener ID: \(screeningID)] Processing with model '\(UnifiedModelName)'. Threshold: \(probabilityThreshold)")

        let request = VNCoreMLRequest(model: modelToUse.model)
        request.usesCPUOnly = true

        var allObservations: [CSKShared.Classification] = [] // Use fully qualified name if needed
        var currentDecisiveDetection: CSKShared.Classification? = nil

        do {
            try handler.perform([request])

            guard let results = request.results as? [VNClassificationObservation] else {
                print("  [ScaryCatScreener ID: \(screeningID)] Warning: No classification results from model '\(UnifiedModelName)'.")
                // Return empty report or throw, depending on desired strictness
                return ScreeningReport(decisiveDetection: nil, allClassifications: []) 
            }

            if results.isEmpty {
                print("  [ScaryCatScreener ID: \(screeningID)] Warning: Model '\(UnifiedModelName)' returned empty results.")
                return ScreeningReport(decisiveDetection: nil, allClassifications: [])
            }
            
            print("  [ScaryCatScreener ID: \(screeningID)] Class confidences from '\(UnifiedModelName)':")
            for observation in results {
                let classification = CSKShared.Classification(identifier: observation.identifier, confidence: observation.confidence)
                allObservations.append(classification)
                
                print("    - Class: \(classification.identifier), Confidence: \(String(format: "%.4f", classification.confidence))")
                
                // Ignore "safe" class for decisive detection, even if it's above threshold.
                if classification.identifier.lowercased() != "safe" { // Check against "safe" (case-insensitive)
                    if currentDecisiveDetection == nil && classification.confidence >= probabilityThreshold {
                        print("  [ScaryCatScreener ID: \(screeningID)] ---> Threshold exceeded for class '\(classification.identifier)'. Feature detected.")
                        currentDecisiveDetection = classification
                    }
                }
            }

        } catch {
            print("  [ScaryCatScreener ID: \(screeningID)] Error performing Vision request for model '\(UnifiedModelName)': \(error).")
            print("--- [ScaryCatScreener] Image screening finished with error (ID: \(screeningID)) ---")
            throw NSError(domain: Self.errorDomain,
                          code: ErrorCode.predictionFailed.rawValue,
                          userInfo: [
                              NSLocalizedDescriptionKey: "Vision request failed for model \(UnifiedModelName).",
                              NSUnderlyingErrorKey: error
                          ])
        }
        
        let report = ScreeningReport(decisiveDetection: currentDecisiveDetection, allClassifications: allObservations.sorted(by: { $0.confidence > $1.confidence }))

        if currentDecisiveDetection != nil {
            print("[ScaryCatScreener ID: \(screeningID)] Screening complete. Feature detected.")
        } else {
            print("[ScaryCatScreener ID: \(screeningID)] Screening complete. No class exceeded threshold (\(probabilityThreshold)). Image is Safe.")
        }
        print("--- [ScaryCatScreener] Image screening finished (ID: \(screeningID)) ---")
        return report
    }
}
