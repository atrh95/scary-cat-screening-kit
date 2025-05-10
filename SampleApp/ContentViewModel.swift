import ScaryCatScreeningKit
import Combine
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

    private let screener: ScaryCatScreener?
    private let catApiBaseUrl = "https://api.thecatapi.com/v1/images/search?limit=10"

    init() {
        do {
            screener = try ScaryCatScreener()
        } catch {
            screener = nil
            let errorDesc = "スクリーナーの初期化に失敗: \(error.localizedDescription)"
            errorMessage = errorDesc
            screeningSummary = errorDesc // 初期化エラーもサマリーに表示
        }
    }

    // MARK: - Image Fetching and Screening Flow

    func fetchAndScreenImagesFromCatAPI(count: Int = 5) {
        guard let screener else {
            updateStateForScreenerNotInitialized()
            return
        }

        guard let apiUrl = URL(string: "\(catApiBaseUrl)\(count)") else {
            updateStateForInvalidURL()
            return
        }

        isLoading = true
        resetPublishedPropertiesForNewFetch()
        screeningSummary = "猫APIから画像情報を取得中..."

        Task {
            do {
                let catImageResponses = try await _fetchCatImageResponses(from: apiUrl)
                guard !catImageResponses.isEmpty else {
                    updateStateForNoImagesFoundFromAPI()
                    return
                }
                screeningSummary = "\(catImageResponses.count)件の画像情報を取得。ダウンロード中..."

                let downloadedImages = await _downloadImages(from: catImageResponses)
                self.fetchedImages = downloadedImages
                guard !downloadedImages.isEmpty else {
                    updateStateForDownloadFailed()
                    return
                }
                screeningSummary = "\(downloadedImages.count)枚の画像をダウンロード完了。スクリーニング中..."

                let safeImages = try await screener.screen(images: downloadedImages, probabilityThreshold: 0.65)
                updateStateForScreeningComplete(safeImages: safeImages, totalDownloaded: downloadedImages.count)

            } catch {
                handleFetchAndScreenError(error)
            }
            self.isLoading = false
        }
    }

    // MARK: - Private Helper Methods for Fetching and Screening

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
                    try? await Task.sleep(nanoseconds: 10_000_000) // Slight delay for simulation if needed
                    do {
                        let (imgData, _) = try await URLSession.shared.data(from: imageUrl)
                        return UIImage(data: imgData)
                    } catch {
                        // Optionally log individual download errors here if needed,
                        // but the current design handles empty downloadedImages array later.
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

    // MARK: - State Update Helper Methods

    private func resetPublishedPropertiesForNewFetch() {
        errorMessage = nil
        fetchedImages = []
        safeImagesForDisplay = []
    }

    private func updateStateForScreenerNotInitialized() {
        errorMessage = "スクリーナーが初期化されていません。"
        screeningSummary = "エラー: スクリーナー未初期化"
        isLoading = false // Ensure loading stops if it was started
    }

    private func updateStateForInvalidURL() {
        errorMessage = "無効なAPI URLです。"
        screeningSummary = "エラー: API URL不正"
        isLoading = false
    }

    private func updateStateForNoImagesFoundFromAPI() {
        screeningSummary = "猫APIから画像が見つかりませんでした。"
        isLoading = false
    }

    private func updateStateForDownloadFailed() {
        screeningSummary = "画像のダウンロードに全て失敗しました。"
        isLoading = false
    }

    private func updateStateForScreeningComplete(safeImages: [UIImage], totalDownloaded: Int) {
        safeImagesForDisplay = safeImages
        screeningSummary = "処理完了。安全な画像: \(safeImages.count)枚 / \(totalDownloaded)枚"
    }

    private func handleFetchAndScreenError(_ error: Error) {
        switch error {
            case let decodingError as DecodingError:
                errorMessage = "APIレスポンスの解析エラー: \(decodingError.localizedDescription)"
                screeningSummary = "エラー: APIレスポンス解析失敗"
            case let screenerError as ScaryCatScreenerError:
                errorMessage = "スクリーニングエラー: \(screenerError.localizedDescription)"
                screeningSummary = "エラー: スクリーニング処理失敗"
            default:
                errorMessage = "予期せぬエラー: \(error.localizedDescription)"
                screeningSummary = "エラー: 不明な問題発生"
        }
    }
}
