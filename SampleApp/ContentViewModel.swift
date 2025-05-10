import Combine
import ScaryCatScreeningKit
import SwiftUI

struct CatImageResponse: Decodable, Identifiable {
    let id: String
    let url: String
    let width: Int?
    let height: Int?
}

@MainActor
final class ContentViewModel: ObservableObject {
    @Published var fetchedImages: [UIImage] = [] // APIから取得・ダウンロードした画像
    @Published var safeImagesForDisplay: [UIImage] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var screeningSummary: String = ""

    private let screener: MultiClassScaryCatScreener?
    private let catApiBaseUrl = "https://api.thecatapi.com/v1/images/search?limit=10"

    init() {
        do {
            screener = try MultiClassScaryCatScreener()
        } catch let error as NSError {
            screener = nil
            let errorDesc = "スクリーナーの初期化に失敗: \(error.localizedDescription) (コード: \(error.code), ドメイン: \(error.domain))"
            errorMessage = errorDesc
            screeningSummary = errorDesc // 初期化エラーもサマリーに表示
            if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error {
                print("初期化エラーの原因: \(underlying.localizedDescription)")
            }
        }
    }

    // MARK: - 画像の取得とスクリーニングフロー

    func fetchAndScreenImagesFromCatAPI(count: Int = 5) {
        guard let screener else {
            errorMessage = "スクリーナーが初期化されていません。"
            screeningSummary = "エラー: スクリーナー未初期化"
            isLoading = false
            return
        }

        guard let apiUrl = URL(string: "\(catApiBaseUrl)\(count)") else {
            errorMessage = "無効なAPI URLです。"
            screeningSummary = "エラー: API URL不正"
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil
        fetchedImages = []
        safeImagesForDisplay = []
        screeningSummary = "猫APIから画像情報を取得中..."

        Task {
            do {
                let catImageResponses = try await _fetchCatImageResponses(from: apiUrl)
                guard !catImageResponses.isEmpty else {
                    self.screeningSummary = "猫APIから画像が見つかりませんでした。"
                    self.isLoading = false
                    return
                }
                screeningSummary = "\(catImageResponses.count)件の画像情報を取得。ダウンロード中..."

                let downloadedImages = await _downloadImages(from: catImageResponses)
                self.fetchedImages = downloadedImages
                guard !downloadedImages.isEmpty else {
                    self.screeningSummary = "画像のダウンロードに全て失敗しました。"
                    self.isLoading = false
                    return
                }
                screeningSummary = "\(downloadedImages.count)枚の画像をダウンロード完了。スクリーニング中..."

                // スクリーニングを実行
                let safeImages = try await screener.screen(
                    images: downloadedImages,
                    probabilityThreshold: 0.65,
                    enableLogging: true
                )

                self.safeImagesForDisplay = safeImages
                self.screeningSummary = "処理完了。安全な画像: \(safeImages.count)枚 / \(downloadedImages.count)枚"

            } catch {
                handleFetchAndScreenError(error)
            }
            self.isLoading = false
        }
    }

    // MARK: - 取得とスクリーニングのプライベートメソッド

    private func _fetchCatImageResponses(from url: URL) async throws -> [CatImageResponse] {
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([CatImageResponse].self, from: data)
    }

    private func _downloadImages(from responses: [CatImageResponse]) async -> [UIImage] {
        var downloadedImgs: [UIImage] = []
        await withTaskGroup(of: UIImage?.self) { group in
            for response in responses {
                guard let imageUrl = URL(string: response.url) else { continue }
                group.addTask {
                    try? await Task.sleep(nanoseconds: 10_000_000)
                    do {
                        let (imgData, _) = try await URLSession.shared.data(from: imageUrl)
                        return UIImage(data: imgData)
                    } catch {
                        return nil
                    }
                }
            }
            for await image in group {
                if let image {
                    downloadedImgs.append(image)
                }
            }
        }
        return downloadedImgs
    }

    private func handleFetchAndScreenError(_ error: Error) {
        switch error {
            case let decodingError as DecodingError:
                errorMessage = "APIレスポンスの解析エラー: \(decodingError.localizedDescription)"
                screeningSummary = "エラー: APIレスポンス解析失敗"
            default:
                var finalErrorMessage = "予期せぬエラー: \(error.localizedDescription)"
                var finalScreeningSummary = "エラー: 不明な問題発生"

                if let nsError = error as? NSError {
                    finalErrorMessage =
                        "エラー: \(nsError.localizedDescription) (ドメイン: \(nsError.domain), コード: \(nsError.code))"
                    finalScreeningSummary = "エラー (ドメイン: \(nsError.domain), コード: \(nsError.code))"
                    if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                        print("原因: \(underlying.localizedDescription)")
                    }
                }
                errorMessage = finalErrorMessage
                screeningSummary = finalScreeningSummary
        }
    }
}
