import SwiftUI
import Combine
import CSKShared
import CatScreeningKit

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
    private let numberOfRuns = 1 // 判定回数

    init() {
        // スクリーンショットを初期化
        self.screener = ScaryCatScreener()
        if self.screener == nil {
            print("Error: Failed to initialize ScaryCatScreener.")
            // 初期化失敗時のエラーハンドリング
            self.error1 = "Screener initialization failed."
            self.error2 = "Screener initialization failed."
        }
    }

    func processImage1() {
        Task {
            self.isLoading1 = true
            self.error1 = nil
            self.results1.removeAll()

            // 画像を一度だけ取得
            guard let imageData = await fetchImageData(url: url1, errorBinding: \.error1),
                  let uiImage = UIImage(data: imageData) else {
                self.isLoading1 = false
                return
            }
            self.image1 = uiImage

            // 複数回判定を実行
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

            // 画像を一度だけ取得
            guard let imageData = await fetchImageData(url: url2, errorBinding: \.error2),
                  let uiImage = UIImage(data: imageData) else {
                self.isLoading2 = false
                return
            }
            self.image2 = uiImage

            // 複数回判定を実行
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

    // 画像データ取得
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

    // 画像判定処理
    private func screenImageInternal(
        image: UIImage,
        runIndex: Int,
        resultsBinding: ReferenceWritableKeyPath<ContentViewModel, [String]>,
        errorBinding: ReferenceWritableKeyPath<ContentViewModel, String?>
    ) async {
        guard let screener else {
            let errorMsg = "Screener not initialized."
            self[keyPath: errorBinding] = errorMsg
            // 結果配列にもエラーを追加
            self[keyPath: resultsBinding].append("Run \(runIndex): Error - \(errorMsg)")
            return
        }

        do {
            // 画像判定
            print("Screening image (Run \(runIndex))...")
            let screeningResult = try await screener.screen(image: image)
            let resultString = "Run \(runIndex): \(screeningResult.label) (\(String(format: "%.2f", screeningResult.confidence)))"
            self[keyPath: resultsBinding].append(resultString)
            print("Screening complete (Run \(runIndex)): \(screeningResult.label)")

        } catch {
            let errorMsg = error.localizedDescription
            print("Error screening image (Run \(runIndex)): \(errorMsg)")
            self[keyPath: errorBinding] = errorMsg // 最後のエラーを保持
            self[keyPath: resultsBinding].append("Run \(runIndex): Error - \(errorMsg)")
        }
    }
} 
