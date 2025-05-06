# ScaryCatScreener

`CatScreeningKit` フレームワークの一部として提供される、具体的な猫画像スクリーナーです。

## 概要

`ScaryCatScreener` は、同梱の `ScaryCatScreeningML.mlmodel` を使用して、与えられた猫の画像が特定のカテゴリに分類されるか判定します。

## 使用方法 (Usage)

### 1. インポート

```swift
import CatScreeningKit
```

### 2. 初期化

モデルのロードに失敗する可能性があるため、初期化子は `init?` となっています。

```swift
guard let screener = ScaryCatScreener() else {
    // 初期化失敗時の処理 (例: エラーログ、代替処理)
    fatalError("ScaryCatScreener の初期化に失敗")
}
// screener を使用
```

### 3. 予測の実行 (`async/await`)

`screen` メソッドは `async throws` なので、`Task` や `async` 関数内で `try await` を使って呼び出します。

```swift
guard let image = yourUIImage else { return } // 有効な UIImage を用意

Task {
    do {
        let report = try await screener.screen(image: image)
        if let detection = report.decisiveDetection {
            print("決定的な検出: \(detection.identifier), 信頼度: \(detection.confidence)")
        } else {
            print("決定的な検出なし (安全と判断)")
        }
        print("全分類:")
        for classification in report.allClassifications {
            print("  - \(classification.identifier): \(classification.confidence)")
        }
        // 予測結果に基づいた処理 (UI更新は @MainActor などでメインスレッドを保証)

    } catch let error as PredictionError {
        print("予測失敗: \(error)")
        // PredictionError に応じた処理
    } catch {
        print("予期せぬエラー: \(error)")
        // その他のエラー処理
    }
}
```

## 使用モデル

- `CatScreeningKit/Sources/Screeners/ScaryCatScreener/Resources` ディレクトリ内の `ScaryCatScreeningML.mlmodel` が利用されます。
- このモデルはビルド時にコンパイルされ、パッケージに含まれます。 