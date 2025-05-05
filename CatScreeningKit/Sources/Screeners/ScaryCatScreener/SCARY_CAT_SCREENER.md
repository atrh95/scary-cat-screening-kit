# ScaryCatScreener

`CatScreeningKit` フレームワークの初期実装として提供される、具体的な猫画像スクリーナーです。

## 概要

`ScaryCatScreener` は `CatScreenerProtocol` に準拠し、同梱の `ScaryCatScreeningML.mlmodel` を使用して、与えられた猫の画像が「怖い」か「怖くない」かを分類します。

## 使用方法 (Usage)

### 1. インポート

```swift
import CatScreeningKit
```

### 2. 初期化

モデルのロードに失敗する可能性があるため、初期化子は `init?` となっています。

```swift
guard var screener = ScaryCatScreener() else {
    // 初期化失敗時の処理 (例: エラーログ、代替処理)
    fatalError("ScaryCatScreener の初期化に失敗")
}
// screener を使用
```

または、共有インスタンスを利用します（nilチェックが必要です）。

```swift
guard var sharedScreener = ScaryCatScreener.shared else {
    // 共有インスタンスが利用できない場合の処理
    fatalError("共有 ScaryCatScreener インスタンスが利用できません")
}
// sharedScreener を使用
```
*Note: `CatScreenerProtocol` の `minConfidence` は `var` なので、必要に応じて値を変更できます。共有インスタンスの値を変更すると、他の箇所での利用にも影響します。*

### 3. 予測の実行 (`async/await`)

`screen` メソッドは `async throws` なので、`Task` や `async` 関数内で `try await` を使って呼び出します。

```swift
guard let image = yourUIImage else { return } // 有効な UIImage を用意

Task {
    do {
        // 最小信頼度を設定 (任意)
        // screener.minConfidence = 0.8 // 例: 80%

        let prediction = try await screener.screen(image: image)
        print("予測ラベル: \\(prediction.label), 信頼度: \\(prediction.confidence)")
        // 予測結果に基づいた処理 (UI更新は @MainActor などでメインスレッドを保証)

    } catch let error as PredictionError {
        print("予測失敗: \\(error)")
        // PredictionError に応じた処理
    } catch {
        print("予期せぬエラー: \\(error)")
        // その他のエラー処理
    }
}
```

## 使用モデル

- `CatScreeningKit/Sources/Screeners/ScaryCatScreener/Resources` ディレクトリ内の `ScaryCatScreeningML.mlmodel` が利用されます。
- このモデルはビルド時にコンパイルされ、パッケージに含まれます。 