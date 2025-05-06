@testable import CatScreeningKit
import XCTest

final class ScaryCatScreenerTests: XCTestCase {
    var screener: ScaryCatScreener!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // モデル読込失敗時はここでテストが失敗
        screener = try ScaryCatScreener()
    }

    override func tearDownWithError() throws {
        screener = nil
        try super.tearDownWithError()
    }

    // ScaryCatScreenerが正常に初期化されることを確認
    func testScaryCatScreenerInitialization_Succeeds() throws {
        XCTAssertNotNil(screener, "ScaryCatScreener の初期化成功")
    }

    // 空の画像配列をスクリーニングした際に空配列が返ることを確認
    func testScreen_WithEmptyImageArray_ReturnsEmpty() async throws {
        let images: [UIImage] = []
        let safeImages = try await screener.screen(images: images)
        XCTAssertTrue(safeImages.isEmpty, "空の画像配列スクリーニング時、空配列を返却")
    }

    // 空のUIImage作成ヘルパー
    private func createBlankUIImage(size: CGSize = CGSize(width: 10, height: 10)) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    // 有効な単一画像（空画像）をスクリーニングした際に、その画像が返ることを確認
    func testScreen_WithOneValidImage_ReturnsOneImage() async throws {
        guard let blankImage = createBlankUIImage() else {
            XCTFail("テスト用空画像作成失敗")
            return
        }
        let images: [UIImage] = [blankImage]
        
        // ログを有効にして実行。安全判定の閾値を100%にして、このテストではモデル判定によらず画像が返ることを期待
        let safeImages = try await screener.screen(images: images, probabilityThreshold: 1.0, enableLogging: true)
        
        XCTAssertEqual(safeImages.count, 1, "有効（空）画像1枚スクリーニング時、安全と仮定して1枚返却")
        if !safeImages.isEmpty {
            XCTAssertEqual(safeImages[0], blankImage, "返却画像は入力画像と同一")
        }
    }

    // CGImageに変換できない画像がスクリーニング処理から除外されることを確認
    func testScreen_WithNonConvertibleToCGImage_FiltersOutImage() async throws {
        // UIImage() は cgImage や ciImage を持たない空の画像を生成する
        let invalidImage = UIImage()
        let images: [UIImage] = [invalidImage]
        
        // コンソール出力を抑制するため、このテストではログを無効化
        let safeImages = try await screener.screen(images: images, enableLogging: false)
        
        XCTAssertTrue(safeImages.isEmpty, "CGImage変換不可画像は除外、結果は空配列")
    }
    
    // 有効な画像と無効な画像が混在する場合に、有効な画像のみが返ることを確認
    func testScreen_WithMixedValidAndInvalidImages() async throws {
        guard let blankImage = createBlankUIImage() else {
            XCTFail("テスト用空画像作成失敗")
            return
        }
        // この画像はVisionで処理できない
        let invalidImage = UIImage()
        
        let images: [UIImage] = [blankImage, invalidImage, blankImage]
        
        // ログを有効にして実行。安全判定の閾値を100%にして、このテストではモデル判定によらず有効画像が返ることを期待
        let safeImages = try await screener.screen(images: images, probabilityThreshold: 1.0, enableLogging: true)
        
        XCTAssertEqual(safeImages.count, 2, "有効画像のみ返却")
        if safeImages.count == 2 {
            XCTAssertTrue(safeImages.allSatisfy { $0 === blankImage }, "返却画像は全て有効な空画像")
        }
    }
}
