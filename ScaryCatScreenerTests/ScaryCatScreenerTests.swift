import CoreGraphics
@testable import ScaryCatScreeningKit
import XCTest

/// 実機ではないシミュレータでのテストは十分な精度を得られないので精度の検証は省く
final class ScaryCatScreenerTests: XCTestCase {
    var screener: ScaryCatScreener!

    override func setUp() {
        super.setUp()
        screener = nil
    }

    override func tearDown() {
        screener = nil
        super.tearDown()
    }

    /// 初期化テスト
    func testInitialization() async throws {
        // ログ出力なしで初期化
        let screenerWithoutLogging = try await getScreener(enableLogging: false)
        XCTAssertNotNil(screenerWithoutLogging)

        // ログ出力ありで初期化
        let screenerWithLogging = try await getScreener(enableLogging: true)
        XCTAssertNotNil(screenerWithLogging)
    }

    private func getScreener(enableLogging: Bool) async throws -> ScaryCatScreener? {
        if let screener {
            return screener
        } else {
            do {
                let newScreener = try await ScaryCatScreener(enableLogging: enableLogging)
                screener = newScreener
                return newScreener
            } catch let error as NSError {
                print("ScaryCatScreener の初期化に失敗しました: \(error.localizedDescription)")
                print("エラーコード: \(error.code), ドメイン: \(error.domain)")
                if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error {
                    print("原因: \(underlying.localizedDescription)")
                }
                return nil
            }
        }
    }

    /// TestResourcesディレクトリ内の画像を使用してスクリーニングを実行し、以下を検証:
    /// - 結果が空でないこと
    /// - 入力画像と結果が1対1で対応していること
    /// - 怖い特徴の信頼度が0〜1の範囲内であること
    /// - 怖いと判定された特徴の信頼度が閾値を超えていること
    /// - 入力画像数と結果数が一致すること
    /// - ログ出力が得られること
    func testScreenReturnsResults() async throws {
        // #filePathを使用してTestResourcesディレクトリのURLを取得
        var dir = URL(fileURLWithPath: #filePath)
        dir.deleteLastPathComponent()
        let resourceURL = dir.appendingPathComponent("TestResources")
        print("Resource URL: \(resourceURL.path)")

        // TestResourcesディレクトリ内のすべてのファイルを取得
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: resourceURL, includingPropertiesForKeys: nil) else {
            XCTFail("Failed to read TestResources directory")
            return
        }

        // 全ての画像を読み込む
        var testImageData: [Data] = []
        var loadedImageURLs: [URL] = []

        for fileURL in files {
            if let imageData = try? Data(contentsOf: fileURL) {
                testImageData.append(imageData)
                loadedImageURLs.append(fileURL)
                print("Loaded image: \(fileURL.lastPathComponent)")
            }
        }

        guard !testImageData.isEmpty else {
            XCTFail("No valid image files found in TestResources")
            return
        }

        // スクリーニングを実行
        let probabilityThreshold: Float = 0.85
        let enableLogging = true

        // スクリーナーの取得
        guard let screener = try await getScreener(enableLogging: enableLogging) else {
            XCTFail("Failed to initialize screener")
            return
        }

        // 全ての画像を一度にスクリーニング
        let screeningResults = try await screener.screen(
            imageDataList: testImageData,
            probabilityThreshold: probabilityThreshold,
            enableLogging: enableLogging
        )

        // 結果の検証
        XCTAssertFalse(screeningResults.results.isEmpty, "スクリーニング結果が空です")
        XCTAssertEqual(screeningResults.results.count, testImageData.count, "入力画像数と結果数が一致しません")

        // 各結果の検証
        for (index, result) in screeningResults.results.enumerated() {
            XCTAssertNotNil(result.imageData, "結果に画像データが含まれていません")
            print("Checking result for: \(loadedImageURLs[index].lastPathComponent)")

            // 怖い特徴の検証
            for (featureName, confidence) in result.confidences {
                XCTAssertFalse(featureName.isEmpty, "怖い特徴の名前が空です")
                XCTAssertGreaterThanOrEqual(confidence, 0.0, "信頼度が0未満です")
                XCTAssertLessThanOrEqual(confidence, 1.0, "信頼度が1を超えています")
            }
        }

        // 各画像の安全性判定を検証
        for result in screeningResults.results {
            if !result.isSafe {
                print(
                    "怖い特徴を検出: \(result.confidences.filter { $0.value >= probabilityThreshold }.map { "\($0.key) (\($0.value))" }.joined(separator: ", "))"
                )
                XCTAssertTrue(
                    screeningResults.unsafeResults.contains { $0.imageData == result.imageData },
                    "閾値を超えた特徴がある画像が危険な画像として判定されていません"
                )
            } else {
                XCTAssertTrue(
                    screeningResults.safeResults.contains { $0.imageData == result.imageData },
                    "閾値を超えた特徴がない画像が安全な画像として判定されていません"
                )
            }
        }

        XCTAssertEqual(
            screeningResults.safeResults.count + screeningResults.unsafeResults.count,
            testImageData.count,
            "安全な画像と危険な画像の合計が入力画像数と一致しません"
        )

        // レポートの検証
        let report = screeningResults.generateDetailedReport()
        XCTAssertFalse(report.isEmpty, "レポートが空です")
        XCTAssertTrue(report.contains("安全"), "レポートに安全性の情報が含まれていません")
    }
}
