import SwiftUI
import Combine
import CSKShared
import CatScreeningKit

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
            self.screener = try ScaryCatScreener()
        } catch {
            self.screener = nil
            let errorDesc = "スクリーナーの初期化に失敗: \(error.localizedDescription)"
            self.errorMessage = errorDesc
            self.screeningSummary = errorDesc // 初期化エラーもサマリーに表示
        }
    }

    func fetchAndScreenImagesFromCatAPI(count: Int = 5) {
        guard let screener = self.screener else {
            self.errorMessage = "スクリーナーが初期化されていません。"
            self.screeningSummary = "エラー: スクリーナー未初期化"
            return
        }
        
        guard let url = URL(string: "\(catApiBaseUrl)\(count)") else {
            self.errorMessage = "無効なAPI URLです。"
            self.screeningSummary = "エラー: API URL不正"
            return
        }

        self.isLoading = true
        self.errorMessage = nil
        self.fetchedImages = []
        self.safeImagesForDisplay = []
        self.screeningSummary = "猫APIから画像情報を取得中..."

        Task {
            do {
                // 1. Cat APIから画像URLリストを取得
                let (data, _) = try await URLSession.shared.data(from: url)
                let catImageResponses = try JSONDecoder().decode([CatImageResponse].self, from: data)
                
                if catImageResponses.isEmpty {
                    self.screeningSummary = "猫APIから画像が見つかりませんでした。"
                    self.isLoading = false
                    return
                }
                self.screeningSummary = "\(catImageResponses.count)件の画像情報を取得。ダウンロード中..."

                // 2. 各URLから画像を非同期にダウンロード
                var downloadedImages: [UIImage] = []
                await withTaskGroup(of: UIImage?.self) { group in
                    for response in catImageResponses {
                        guard let imageUrl = URL(string: response.url) else { continue }
                        group.addTask {
                            do {
                                let (imgData, _) = try await URLSession.shared.data(from: imageUrl)
                                return UIImage(data: imgData)
                            } catch {
                                return nil
                            }
                        }
                    }
                    for await image in group {
                        if let image = image {
                            downloadedImages.append(image)
                        }
                    }
                }
                
                self.fetchedImages = downloadedImages
                if downloadedImages.isEmpty {
                    self.screeningSummary = "画像のダウンロードに全て失敗しました。"
                    self.isLoading = false
                    return
                }
                self.screeningSummary = "\(downloadedImages.count)枚の画像をダウンロード完了。スクリーニング中..."

                // 3. ダウンロードした画像をスクリーニング
                let safeImages = try await screener.screen(images: downloadedImages, probabilityThreshold: 0.65)
                
                self.safeImagesForDisplay = safeImages
                self.screeningSummary = "処理完了。安全な画像: \(safeImages.count)枚 / \(downloadedImages.count)枚"

            } catch let decodingError as DecodingError {
                self.errorMessage = "APIレスポンスの解析エラー: \(decodingError.localizedDescription)"
                self.screeningSummary = "エラー: APIレスポンス解析失敗"
            } catch let screenerError as ScaryCatScreenerError {
                self.errorMessage = "スクリーニングエラー: \(screenerError.localizedDescription)"
                self.screeningSummary = "エラー: スクリーニング処理失敗"
            } catch {
                self.errorMessage = "予期せぬエラー: \(error.localizedDescription)"
                self.screeningSummary = "エラー: 不明な問題発生"
            }
            self.isLoading = false
        }
    }
} 
