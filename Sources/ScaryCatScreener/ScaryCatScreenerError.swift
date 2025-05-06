import Foundation

// ScaryCatScreenerで発生しうるエラー定義
public enum ScaryCatScreenerError: Error, LocalizedError {
    case resourceBundleNotFound
    case modelLoadingFailed(underlyingError: Error? = nil)
    case invalidImage
    case predictionFailed(underlyingError: Error? = nil)

    public static let errorDomain = "com.akitorahayashi.ScaryCatScreener.ErrorDomain"

    // ローカライズされたエラーメッセージ
    public var errorDescription: String? {
        switch self {
            case .resourceBundleNotFound:
                return "リソースバンドルが見つかりませんでした。"
            case let .modelLoadingFailed(underlyingError):
                var message = "モデルのロードに失敗しました。"
                if let error = underlyingError {
                    message += " 原因: \(error.localizedDescription)"
                }
                return message
            case .invalidImage:
                return "無効な画像形式です。CGImageに変換できませんでした。"
            case let .predictionFailed(underlyingError):
                var message = "Visionリクエストの実行に失敗しました。"
                if let error = underlyingError {
                    message += " 原因: \(error.localizedDescription)"
                }
                return message
        }
    }

    // NSErrorインスタンスへ変換
    public func toNSError() -> NSError {
        var userInfo: [String: Any] = [NSLocalizedDescriptionKey: errorDescription ?? ""]

        let errorCode: Int
        switch self {
            case .resourceBundleNotFound:
                errorCode = 1
            case let .modelLoadingFailed(underlyingError):
                errorCode = 2
                if let error = underlyingError {
                    userInfo[NSUnderlyingErrorKey] = error
                }
            case .invalidImage:
                errorCode = 3
            case let .predictionFailed(underlyingError):
                errorCode = 4
                if let error = underlyingError {
                    userInfo[NSUnderlyingErrorKey] = error
                }
        }
        return NSError(domain: Self.errorDomain, code: errorCode, userInfo: userInfo)
    }
}
