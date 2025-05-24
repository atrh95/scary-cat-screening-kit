import Combine
import ScaryCatScreeningKit
import SwiftUI
import Kingfisher

struct CatImageResponse: Decodable, Identifiable {
    let id: String
    let url: String
    let width: Int?
    let height: Int?
}

struct UnsafeImageResult {
    let image: UIImage
    let url: URL
    let features: [DetectedScaryFeature]
}

@MainActor
class ScreeningViewModel: ObservableObject {
    @Published private(set) var fetchedImages: [(image: UIImage, url: URL)] = []
    @Published private(set) var safeImagesForDisplay: [(image: UIImage, url: URL)] = []
    @Published private(set) var unsafeImagesForDisplay: [UnsafeImageResult] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isScreenerReady = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var screeningSummary: String = ""
    
    private var screener: ScaryCatScreener?
    private let imageDownloader: ImageDownloader
    private let imageCache: ImageCache
    
    init() {
        // キャッシュの設定
        imageCache = ImageCache.default
        imageCache.memoryStorage.config.expiration = .days(1)
        imageCache.diskStorage.config.expiration = .days(1)
        imageCache.memoryStorage.config.totalCostLimit = 500 * 1024 * 1024  // 500MB
        imageCache.diskStorage.config.sizeLimit = 500 * 1024 * 1024  // 500MB
        
        // ダウンローダーの設定
        imageDownloader = ImageDownloader.default
        imageDownloader.downloadTimeout = 15
        
        Task {
            do {
                self.screener = try await ScaryCatScreener(enableLogging: true)
                self.isScreenerReady = true
            } catch {
                self.errorMessage = "スクリーナーの初期化に失敗しました: \(error.localizedDescription)"
            }
        }
    }
    
    func fetchAndScreenImagesFromCatAPI(count: Int) {
        Task {
            isLoading = true
            errorMessage = nil
            fetchedImages = []
            safeImagesForDisplay = []
            unsafeImagesForDisplay = []
            screeningSummary = ""
            
            do {
                // Cat APIから画像URLを取得
                let url = URL(string: "https://api.thecatapi.com/v1/images/search?limit=\(count)")!
                let (data, _) = try await URLSession.shared.data(from: url)
                let responses = try JSONDecoder().decode([CatImageResponse].self, from: data)
                
                guard let screener = screener else {
                    throw NSError(domain: "ScreeningViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Screener not initialized"])
                }
                
                let probabilityThreshold: Float = 0.85
                let enableLogging = true
                
                // 画像を直列でダウンロード
                for response in responses {
                    guard let url = URL(string: response.url) else { continue }
                    
                    do {
                        // Kingfisherを使用して画像をダウンロード
                        let image = try await withCheckedThrowingContinuation { continuation in
                            KingfisherManager.shared.retrieveImage(
                                with: url,
                                options: [
                                    .cacheOriginalImage,
                                    .cacheMemoryOnly,
                                    .backgroundDecode
                                ]
                            ) { result in
                                switch result {
                                case .success(let value):
                                    continuation.resume(returning: value.image)
                                case .failure(let error):
                                    continuation.resume(throwing: error)
                                }
                            }
                        }
                        
                        guard let cgImage = image.cgImage else { continue }
                        
                        fetchedImages.append((image: image, url: url))
                        let singleResult = try await screener.screen(
                            cgImages: [cgImage],
                            probabilityThreshold: probabilityThreshold,
                            enableLogging: enableLogging
                        )
                        let result = singleResult.results[0]
                        if result.scaryFeatures.isEmpty {
                            safeImagesForDisplay.append((image: image, url: url))
                        } else {
                            unsafeImagesForDisplay.append(UnsafeImageResult(image: image, url: url, features: result.scaryFeatures))
                        }
                    } catch {
                        print("画像のダウンロードに失敗: \(error.localizedDescription)")
                        continue
                    }
                }
                
                screeningSummary = "安全な画像: \(safeImagesForDisplay.count)枚\n危険な画像: \(unsafeImagesForDisplay.count)枚"
                
            } catch {
                self.errorMessage = "エラーが発生しました: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
}
