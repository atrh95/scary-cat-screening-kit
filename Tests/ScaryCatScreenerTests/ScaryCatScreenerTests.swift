@testable import CatScreeningKit // Since CatScreeningKit exports ScaryCatScreener
import XCTest

// If ScaryCatScreener is not directly accessible, you might need to use
// @testable import ScaryCatScreener if it's a separate module target in your Package.swift

final class ScaryCatScreenerTests: XCTestCase {
    var screener: ScaryCatScreener!

    override func setUpWithError() throws {
        // This method is called before the invocation of each test method in the class.
        try super.setUpWithError()
        // Attempt to initialize the screener. If the model isn't found or loadable,
        // tests that depend on it might fail here, which is a valid test of the setup.
        screener = try ScaryCatScreener()
    }

    override func tearDownWithError() throws {
        // This method is called after the invocation of each test method in the class.
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

    // Helper to create a blank UIImage
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

        // 空の画像はモデルが「安全」と判定し、決定的な検出を引き起こさないという前提
        let safeImages = try await screener.screen(images: images)

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

        let safeImages = try await screener.screen(images: images, enableLogging: false)

        XCTAssertEqual(safeImages.count, 2, "有効画像のみ返却")
        if safeImages.count == 2 {
            XCTAssertTrue(safeImages.allSatisfy { $0 === blankImage }, "返却画像は全て有効な空画像")
        }
    }
}
