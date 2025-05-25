import XCTest
import CoreGraphics
@testable import ScaryCatScreeningKit

final class ScaryCatScreenerTests: XCTestCase {
    var screener: ScaryCatScreener!
    
    override func setUp() async throws {
        try await super.setUp()
        screener = try await ScaryCatScreener(enableLogging: true)
    }
    
    /// TestResourcesディレクトリ内の画像を使用してスクリーニングを実行し、以下を検証:
    /// - 結果が空でないこと
    /// - 入力画像と結果が1対1で対応していること
    /// - 怖い特徴の信頼度が0〜1の範囲内であること
    /// - 怖いと判定された特徴の信頼度が閾値を超えていること
    /// - 入力画像数と結果数が一致すること
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
        
        // 各ファイルを画像として読み込めるか試行し、最初に成功したものを使用
        var cgImage: CGImage?
        var selectedImageURL: URL?
        
        for fileURL in files {
            if let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
               let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                cgImage = image
                selectedImageURL = fileURL
                break
            }
        }
        
        guard let image = cgImage, let imageURL = selectedImageURL else {
            XCTFail("No valid image files found in TestResources")
            return
        }
        print("Using image: \(imageURL.lastPathComponent)")
        
        // スクリーニングを実行
        let probabilityThreshold: Float = 0.85
        let results = try await screener.screen(
            cgImages: [image],
            probabilityThreshold: probabilityThreshold,
            enableLogging: true
        )
        
        // 結果の検証
        XCTAssertFalse(results.results.isEmpty, "スクリーニング結果が空です")
        
        // 最初の結果の確認
        let firstResult = results.results[0]
        XCTAssertEqual(firstResult.index, 0, "画像のインデックスが0ではありません")
        XCTAssertNotNil(firstResult.cgImage, "結果に画像が含まれていません")
        
        // 怖い特徴の検証
        for feature in firstResult.scaryFeatures {
            XCTAssertFalse(feature.featureName.isEmpty, "怖い特徴の名前が空です")
            XCTAssertGreaterThanOrEqual(feature.confidence, 0.0, "信頼度が0未満です")
            XCTAssertLessThanOrEqual(feature.confidence, 1.0, "信頼度が1を超えています")
            XCTAssertGreaterThanOrEqual(feature.confidence, probabilityThreshold, "怖い特徴の信頼度が閾値を下回っています")
        }
        
        // 全体の結果の検証
        XCTAssertEqual(results.results.count, 1, "入力画像数と結果数が一致しません")
        XCTAssertEqual(results.safeImages.count + results.scaryFeatures.values.flatMap { $0 }.count, 1, "安全な画像と危険な画像の合計が入力画像数と一致しません")
    }
} 