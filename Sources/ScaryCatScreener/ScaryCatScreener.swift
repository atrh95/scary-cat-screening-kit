import CoreML
import CSKShared
import UIKit
import Vision
import CoreImage
import VideoToolbox

/// Wrapper to mark VNCoreMLModel as Sendable, assuming concurrent request creation is safe.
private struct SendableVNCoreMLModel: @unchecked Sendable {
    let model: VNCoreMLModel
}

/// Represents a single screening model with its associated positive class identifier.
private struct ScreeningModel: Sendable {
    let model: SendableVNCoreMLModel
    let positiveClassName: String
    let modelName: String // For logging/debugging, e.g., "SphynxScreeningML"
}

/// Loads multiple Core ML binary classification models and determines if an image needs manual review.
/// An image needs review only if *none* of the models detect their respective positive feature
/// above a specified confidence threshold.
public final class ScaryCatScreener: CatScreenerProtocol { // Renamed class back and ADDED protocol conformance here

    /// Error domain for ScaryCatScreener errors.
    public static let errorDomain = "com.akitorahayashi.ScaryCatScreener.ErrorDomain"

    /// Error codes for ScaryCatScreener operations.
    private enum ErrorCode: Int {
        case resourceBundleNotFound = 1
        case noModelsFoundInBundle = 2
        case modelLoadingFailed = 3 // Represents failure loading one or more required models
        case invalidImage = 4
        case predictionFailed = 5
        case noModelsLoaded = 6 // Instance has no models ready
    }

    /// The collection of loaded screening models.
    private let screeningModels: [ScreeningModel]

    /// Mapping from model filename stem to the positive class identifier.
    /// Ensure these filenames match your .mlmodelc files (without extension) in Resources.
    private let positiveClassMapping: [String: String] = [
        "SphynxScreeningML": "sphynx",
        "BlackAndWhiteScreeningML": "black_and_white",
        "HumanHandsDetectedScreeningML": "human_hands_detected",
        "MouthOpenScreeningML": "mouth_open"
        // Add other models here if needed
    ]

    // Constants for preprocessing
    private let targetImageSize = CGSize(width: 224, height: 224)
    private let imageNetMean = CIVector(x: 0.485, y: 0.456, z: 0.406)
    private let imageNetStdDev = CIVector(x: 0.229, y: 0.224, z: 0.225)
    private let ciContext = CIContext() // Reuse context for performance

    /// Initializes the screener by loading the required models from the bundle's resources.
    /// Returns `nil` if the resource bundle cannot be found or if any of the required models fail to load.
    public init?() {
        guard let resourceURL = Bundle.module.resourceURL else {
            print("[ScaryCatScreener] Error: Could not get resource bundle URL from Bundle.module.")
            // Optionally, throw or handle this more gracefully depending on context
            return nil
        }

        print("[ScaryCatScreener] Searching for models in resource bundle root: \(resourceURL.path)")

        var loadedModels: [ScreeningModel] = []
        var encounteredError = false

        do {
            let allFilesInResources = try FileManager.default.contentsOfDirectory(at: resourceURL, includingPropertiesForKeys: nil)
            let modelURLs = allFilesInResources.filter { $0.pathExtension == "mlmodelc" }

            if modelURLs.isEmpty {
                print("[ScaryCatScreener] Error: No .mlmodelc files found in resource bundle root: \(resourceURL.path)")
                encounteredError = true // Mark error but continue to check specific models
            } else {
                 print("[ScaryCatScreener] Found .mlmodelc files: \(modelURLs.map { $0.lastPathComponent })")
            }

            // Attempt to load specifically the required models
            for (modelName, positiveClass) in positiveClassMapping {
                guard let modelURL = modelURLs.first(where: { $0.deletingPathExtension().lastPathComponent == modelName }) else {
                    print("[ScaryCatScreener] Error: Required model file '\(modelName).mlmodelc' not found in resources.")
                    encounteredError = true
                    continue // Skip to next required model
                }

                do {
                    let mlModel = try MLModel(contentsOf: modelURL)
                    let visionModel = try VNCoreMLModel(for: mlModel)
                    let screenModel = ScreeningModel(
                        model: SendableVNCoreMLModel(model: visionModel),
                        positiveClassName: positiveClass,
                        modelName: modelName
                    )
                    loadedModels.append(screenModel)
                    print("[ScaryCatScreener] Successfully loaded model '\(modelName)' for class '\(positiveClass)'.")
                } catch {
                    print("[ScaryCatScreener] Error loading model '\(modelName)' from \(modelURL.path): \(error)")
                    encounteredError = true
                    // Decide if one failure invalidates the whole initializer
                    // For now, we mark error and potentially return nil later
                }
            }

        } catch {
            print("[ScaryCatScreener] Error accessing Resources directory: \(error)")
            encounteredError = true
        }

        // Check if all required models were loaded successfully
        if encounteredError || loadedModels.count != positiveClassMapping.count {
             print("[ScaryCatScreener] Error: Failed to load one or more required models. Initialization failed.")
             // Ensure partial loads don't result in a usable object if requirements aren't met
             // Depending on requirements, could allow partial loading, but safer to fail.
             return nil
        }

        if loadedModels.isEmpty {
             print("[ScaryCatScreener] Error: No required models could be loaded successfully.")
             return nil // Should be covered by the check above, but belt-and-suspenders
        }

        self.screeningModels = loadedModels
        print("[ScaryCatScreener] Initialized successfully with \(loadedModels.count) screening models.")
    }

    // MARK: - Screening Logic

    /// Determines if an image contains any of the specific features monitored by the loaded models.
    /// Performs required preprocessing (resize to 224x224, ImageNet normalization).
    /// - Parameters:
    ///   - image: The input `UIImage` to screen.
    ///   - probabilityThreshold: The confidence threshold (0.0 to 1.0). If any model's positive class
    ///                           confidence exceeds this, that feature is considered detected. Defaults to 0.8.
    /// - Returns: A tuple `(category: String, confidence: Float)` containing the positive class name and confidence
    ///            of the *first* feature detected above the threshold. Returns `nil` if no features are detected
    ///            above the threshold across all models.
    /// - Throws: An `Error` if the image cannot be processed or if a prediction error occurs.
    public func screen(image: UIImage, probabilityThreshold: Float = 0.8) async throws -> (category: String, confidence: Float)? {
        let screeningID = UUID().uuidString.prefix(8) // Short unique ID for this screening run
        print("\n--- [ScaryCatScreener] Starting image screening (ID: \(screeningID)) ---")

        guard !screeningModels.isEmpty else {
            print("[ScaryCatScreener ID: \(screeningID)] Error: No models loaded.")
            throw NSError(domain: Self.errorDomain,
                          code: ErrorCode.noModelsLoaded.rawValue,
                          userInfo: [NSLocalizedDescriptionKey: "ScaryCatScreener is not initialized with any models."])
        }

        // --- Manual Preprocessing with Core Image --- START ---
        guard let ciImage = CIImage(image: image) else {
            print("[ScaryCatScreener ID: \(screeningID)] Error: Failed to create CIImage from UIImage.")
            throw NSError(domain: Self.errorDomain,
                          code: ErrorCode.invalidImage.rawValue,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create CIImage from input UIImage."])
        }

        // 1. Resize
        let originalSize = ciImage.extent.size
        let scaleX = targetImageSize.width / originalSize.width
        let scaleY = targetImageSize.height / originalSize.height
        let scaleTransform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        let resizedCIImage = ciImage.transformed(by: scaleTransform)
            .applyingFilter("CILanczosScaleTransform", parameters: [:]) // Use Lanczos for potentially better quality
            .cropped(to: CGRect(origin: .zero, size: targetImageSize))

        // 2. Normalize ((value / 255.0) - mean) / stdDev
        // CIColorMatrix applies: R' = m11*R + m12*G + m13*B + m14*A + v1, etc.
        // We want: R' = (R - mean.x) / stdDev.x = (1/stdDev.x)*R - (mean.x / stdDev.x)
        let norm_r_scale = 1.0 / imageNetStdDev.x
        let norm_g_scale = 1.0 / imageNetStdDev.y
        let norm_b_scale = 1.0 / imageNetStdDev.z

        let norm_r_bias = -imageNetMean.x / imageNetStdDev.x
        let norm_g_bias = -imageNetMean.y / imageNetStdDev.y
        let norm_b_bias = -imageNetMean.z / imageNetStdDev.z

        // Note: Assumes input CIImage pixel values are already scaled 0-1 (Core Image often handles this internally).
        // If not, a scaling step (like dividing by 255) might be needed BEFORE normalization.
        let normalizedCIImage = resizedCIImage.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: norm_r_scale, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: norm_g_scale, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: norm_b_scale, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: norm_r_bias, y: norm_g_bias, z: norm_b_bias, w: 0)
        ])

        // 3. Render to CVPixelBuffer
        var pixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                       Int(targetImageSize.width),
                                       Int(targetImageSize.height),
                                       kCVPixelFormatType_32BGRA, // Common format, check model requirements if needed
                                       attrs,
                                       &pixelBuffer)

        guard status == kCVReturnSuccess, let finalPixelBuffer = pixelBuffer else {
            print("[ScaryCatScreener ID: \(screeningID)] Error: Failed to create CVPixelBuffer (status: \(status)).")
            throw NSError(domain: Self.errorDomain,
                          code: ErrorCode.predictionFailed.rawValue, // Or a new code
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create CVPixelBuffer for model input."])
        }

        ciContext.render(normalizedCIImage, to: finalPixelBuffer)
        // --- Manual Preprocessing with Core Image --- END ---

        // --- Prediction Loop --- (Uses the preprocessed pixelBuffer)
        let handler = VNImageRequestHandler(cvPixelBuffer: finalPixelBuffer, options: [:]) // USE PIXEL BUFFER

        print("[ScaryCatScreener ID: \(screeningID)] Processing with \(screeningModels.count) models. Threshold: \(probabilityThreshold)")

        for screenModel in screeningModels {
            let request = VNCoreMLRequest(model: screenModel.model.model)

            // Performance Hint: usesCPUOnly=true forces CPU. Test GPU performance if needed.
            request.usesCPUOnly = true

            // REMOVED: request.imageCropAndScaleOption = .centerCrop (Resizing handled manually)

            do {
                // Perform the request synchronously.
                try handler.perform([request])

                guard let results = request.results as? [VNClassificationObservation] else {
                    print("  [ScaryCatScreener ID: \(screeningID)] Warning: No classification results for model '\(screenModel.modelName)'. Assuming feature not detected.")
                    continue
                }

                // Print all classification results for the current model
                print("  [ScaryCatScreener ID: \(screeningID)] Predictions for model '\(screenModel.modelName)':")
                for classification in results {
                    print("    - Class: \(classification.identifier), Confidence: \(String(format: "%.4f", classification.confidence))")
                }

                // Find the confidence for the specific positive class this model looks for.
                if let positiveObservation = results.first(where: { $0.identifier == screenModel.positiveClassName }) {
                     let confidence = positiveObservation.confidence
                     print("  [ScaryCatScreener ID: \(screeningID)] Model '\(screenModel.modelName)' target class '\(screenModel.positiveClassName)' confidence: \(String(format: "%.4f", confidence))") // Clarified log
                     if confidence > probabilityThreshold {
                        print("  [ScaryCatScreener ID: \(screeningID)] ---> Threshold exceeded for '\(screenModel.positiveClassName)'. Feature detected.")
                        print("--- [ScaryCatScreener] Image screening finished (ID: \(screeningID)) ---")
                        return (category: screenModel.positiveClassName, confidence: confidence)
                     }
                } else {
                     print("  [ScaryCatScreener ID: \(screeningID)] Warning: Positive class '\(screenModel.positiveClassName)' not found in results for model '\(screenModel.modelName)'.")
                     continue
                }

            } catch {
                print("  [ScaryCatScreener ID: \(screeningID)] Error performing Vision request for model '\(screenModel.modelName)': \(error).")
                print("--- [ScaryCatScreener] Image screening finished with error (ID: \(screeningID)) ---")
                throw NSError(domain: Self.errorDomain,
                              code: ErrorCode.predictionFailed.rawValue,
                              userInfo: [
                                  NSLocalizedDescriptionKey: "Vision request failed for model \(screenModel.modelName).",
                                  NSUnderlyingErrorKey: error
                              ])
            }
        }

        print("[ScaryCatScreener ID: \(screeningID)] Screening complete. No features detected above threshold.")
        print("--- [ScaryCatScreener] Image screening finished (ID: \(screeningID)) ---")
        return nil
    }
}

// Remove the commented-out protocol conformance as it's no longer needed here
/*
// // Optional: If ReviewScreener needs to conform to CatScreenerProtocol
// // extension ReviewScreener: CatScreenerProtocol {
// // ... (conformance code removed) ...
// // }
*/
