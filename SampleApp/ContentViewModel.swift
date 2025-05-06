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
    @Published var image1: UIImage?
    @Published var results1: [String] = []
    @Published var isLoading1: Bool = false
    @Published var error1: String?

    @Published var image2: UIImage?
    @Published var results2: [String] = []
    @Published var isLoading2: Bool = false
    @Published var error2: String?

    private let screener: CatScreenerProtocol?
    private let url1 = URL(string: "https://cdn2.thecatapi.com/images/b9b.jpg")!
    private let url2 = URL(string: "https://cdn2.thecatapi.com/images/MTY3ODIyMQ.jpg")!
    private let catApiUrl = URL(string: "https://api.thecatapi.com/v1/images/search?limit=2")!
    // 判定実行回数
    private let numberOfRuns = 1

    init() {
        // スクリーナーを初期化
        self.screener = ScaryCatScreener()
        if self.screener == nil {
            print("Error: Failed to initialize ScaryCatScreener.")
            // 初期化失敗時のエラー処理
            self.error1 = "Screener initialization failed."
            self.error2 = "Screener initialization failed."
        }
    }

    // ランダム画像取得・判定
    func fetchAndProcessRandomImages() {
        Task {
            self.isLoading1 = true
            self.isLoading2 = true
            self.error1 = nil
            self.error2 = nil
            self.results1.removeAll()
            self.results2.removeAll()
            self.image1 = nil
            self.image2 = nil

            do {
                print("Fetching random cat URLs from The Cat API...")
                let (data, _) = try await URLSession.shared.data(from: catApiUrl)
                if let dataString = String(data: data, encoding: .utf8) {
                    print("DEBUG: Received data from Cat API: \(dataString)")
                } else {
                    print("DEBUG: Received data from Cat API is not valid UTF-8.")
                }
                let randomCatImages = try JSONDecoder().decode([CatImageResponse].self, from: data)
                print("DEBUG: Decoded Cat API response: \(randomCatImages)")

                // APIが2つ以上返せば成功とする
                guard randomCatImages.count >= 2,
                      let url1 = URL(string: randomCatImages[0].url),
                      let url2 = URL(string: randomCatImages[1].url) else
                {
                    throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "Failed to get at least 2 valid URLs from The Cat API."])
                }
                print("Got random URLs: \(url1), \(url2)")

                // 画像1をダウンロード・処理し、完了を待つ
                await processSingleRandomImage(
                    url: url1,
                    imageBinding: \.image1,
                    resultsBinding: \.results1,
                    errorBinding: \.error1
                )
                
                // 画像2をダウンロード・処理し、完了を待つ
                await processSingleRandomImage(
                    url: url2,
                    imageBinding: \.image2,
                    resultsBinding: \.results2,
                    errorBinding: \.error2
                )

            } catch {
                print("Error fetching or decoding random cat URLs: \(error.localizedDescription)")
                self.error1 = "Random Fetch Error: \(error.localizedDescription)"
                self.error2 = "Random Fetch Error: \(error.localizedDescription)"
            }

            self.isLoading1 = false
            self.isLoading2 = false
        }
    }

    // ランダム画像1件の処理
    private func processSingleRandomImage(
        url: URL,
        imageBinding: ReferenceWritableKeyPath<ContentViewModel, UIImage?>,
        resultsBinding: ReferenceWritableKeyPath<ContentViewModel, [String]>,
        errorBinding: ReferenceWritableKeyPath<ContentViewModel, String?>
    ) async {
        guard let imageData = await fetchImageData(url: url, errorBinding: errorBinding),
              let uiImage = UIImage(data: imageData) else {
            return
        }
        self[keyPath: imageBinding] = uiImage

        // 判定を実行
        await screenImageInternal(
            image: uiImage,
            runIndex: 1,
            resultsBinding: resultsBinding,
            errorBinding: errorBinding
        )
    }

    func processImage1() {
        Task {
            self.isLoading1 = true
            self.error1 = nil
            self.results1.removeAll()

            // 画像を取得
            guard let imageData = await fetchImageData(url: url1, errorBinding: \.error1),
                  let uiImage = UIImage(data: imageData) else {
                self.isLoading1 = false
                return
            }
            self.image1 = uiImage

            // 判定を実行
            for i in 1...numberOfRuns {
                await screenImageInternal(
                    image: uiImage,
                    runIndex: i,
                    resultsBinding: \.results1,
                    errorBinding: \.error1
                )
            }
            self.isLoading1 = false
        }
    }

    func processImage2() {
        Task {
            self.isLoading2 = true
            self.error2 = nil
            self.results2.removeAll()

            // 画像を取得
            guard let imageData = await fetchImageData(url: url2, errorBinding: \.error2),
                  let uiImage = UIImage(data: imageData) else {
                self.isLoading2 = false
                return
            }
            self.image2 = uiImage

            // 判定を実行
            for i in 1...numberOfRuns {
                await screenImageInternal(
                    image: uiImage,
                    runIndex: i,
                    resultsBinding: \.results2,
                    errorBinding: \.error2
                )
            }
            self.isLoading2 = false
        }
    }

    // 画像データ取得処理
    private func fetchImageData(url: URL, errorBinding: ReferenceWritableKeyPath<ContentViewModel, String?>) async -> Data? {
        do {
            print("Fetching image from \(url)...")
            let (data, _) = try await URLSession.shared.data(from: url)
            print("Image data fetched (\(data.count) bytes).")
            return data
        } catch {
            print("Error fetching image from \(url): \(error.localizedDescription)")
            self[keyPath: errorBinding] = "Fetch Error: \(error.localizedDescription)"
            return nil
        }
    }

    // 画像判定実行
    private func screenImageInternal(
        image: UIImage,
        runIndex: Int,
        resultsBinding: ReferenceWritableKeyPath<ContentViewModel, [String]>,
        errorBinding: ReferenceWritableKeyPath<ContentViewModel, String?>
    ) async {
        guard let screener else {
            let errorMsg = "Screener not initialized."
            self[keyPath: errorBinding] = errorMsg
            self[keyPath: resultsBinding].append("Run \(runIndex): Error - \(errorMsg)")
            return
        }

        do {
            print("Screening image (Run \(runIndex))...")
            let report: ScreeningReport = try await screener.screen(image: image, probabilityThreshold: 0.8)
            
            var resultLines: [String] = []

            if let detection = report.decisiveDetection {
                resultLines.append("判定結果 (実行\(runIndex)): 要確認 (検出: \(detection.identifier) - 信頼度: \(String(format: "%.3f", detection.confidence)))")
            } else {
                resultLines.append("判定結果 (実行\(runIndex)): 安全です")
            }

            if report.allClassifications.isEmpty {
                resultLines.append("  (各クラスの信頼度情報なし)")
            } else {
                resultLines.append("  各クラスの信頼度:")
                for classification in report.allClassifications {
                    resultLines.append("    - \(classification.identifier): \(String(format: "%.3f", classification.confidence))")
                }
            }
            
            let resultString = resultLines.joined(separator: "\n")
            self[keyPath: resultsBinding].append(resultString)
            print("Screening display string (Run \(runIndex)):\n\(resultString)")

        } catch {
            let errorMsg = error.localizedDescription
            print("Error screening image (Run \(runIndex)): \(errorMsg)")
            self[keyPath: errorBinding] = errorMsg
            self[keyPath: resultsBinding].append("Run \(runIndex): Error - \(errorMsg)")
        }
    }
} 
