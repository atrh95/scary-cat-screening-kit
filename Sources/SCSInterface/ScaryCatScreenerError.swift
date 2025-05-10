import Foundation

public enum ScaryCatScreenerError: Error {
    case resourceBundleNotFound
    case modelLoadingFailed(originalError: Error? = nil)
    case modelNotFound
    case predictionFailed(originalError: Error? = nil)

    public static let errorDomain = "com.ScaryCatScreeningKit.SCSInterface.Error"

    public func asNSError() -> NSError {
        var code: Int
        var userInfo: [String: Any] = [:]

        switch self {
        case .resourceBundleNotFound:
            code = 1
            userInfo[NSLocalizedDescriptionKey] = "The resource bundle required for screening was not found."
            userInfo[NSLocalizedFailureReasonErrorKey] = "Essential application resources might be missing or improperly packaged."
        case .modelLoadingFailed(let originalError):
            code = 2
            userInfo[NSLocalizedDescriptionKey] = "The ML model failed to load."
            if let originalError = originalError {
                userInfo[NSLocalizedFailureReasonErrorKey] = "The model file might be corrupt, inaccessible, or incompatible."
                userInfo[NSUnderlyingErrorKey] = originalError as NSError
            } else {
                userInfo[NSLocalizedFailureReasonErrorKey] = "The model file might be missing or inaccessible, with no further details."
            }
        case .modelNotFound:
            code = 3
            userInfo[NSLocalizedDescriptionKey] = "The ML model file was not found."
            userInfo[NSLocalizedFailureReasonErrorKey] = "The specified model file does not exist at the expected location."
        case .predictionFailed(let originalError):
            code = 4
            userInfo[NSLocalizedDescriptionKey] = "An error occurred during the image screening prediction process."
            if let originalError = originalError {
                userInfo[NSLocalizedFailureReasonErrorKey] = "There was an issue with the Vision framework request or processing its results."
                userInfo[NSUnderlyingErrorKey] = originalError as NSError
            } else {
                userInfo[NSLocalizedFailureReasonErrorKey] = "An unspecified issue occurred with the Vision framework request or result processing."
            }
        }
        return NSError(domain: ScaryCatScreenerError.errorDomain, code: code, userInfo: userInfo)
    }
} 