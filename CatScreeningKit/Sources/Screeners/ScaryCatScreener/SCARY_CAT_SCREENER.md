# ScaryCatScreener

`CatScreeningKit` フレームワークの初期実装として提供される、具体的な猫画像スクリーナーです。

## 概要

`ScaryCatScreener` は `CatScreener` プロトコルに準拠し、同梱の `ScaryCatScreener.mlmodel` を使用して、与えられた猫の画像が「怖い」か「怖くない」かを分類します。

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

または、共有インスタンスを利用します（nilチェックが必要です）。

```swift
guard let sharedScreener = ScaryCatScreener.shared else {
    // 共有インスタンスが利用できない場合の処理
    fatalError("共有 ScaryCatScreener インスタンスが利用できません")
}
// sharedScreener を使用
```

### 3. 予測の実行

`screen` メソッドを `UIImage` インスタンスで呼び出します。

```swift
guard let image = yourUIImage else { return } // 有効な UIImage を用意

screener.screen(image: image, minConfidence: 0.75) { result in
    DispatchQueue.main.async { // UI更新はメインスレッドで
        switch result {
        case .success(let prediction):
            print("予測ラベル: \(prediction.label), 信頼度: \(prediction.confidence)")
            // 予測結果に基づいた処理
        case .failure(let error):
            print("予測失敗: \(error)")
            // エラーに応じた処理 (詳細は PredictionError を参照)
        }
    }
}
```

## 使用モデル

- `CatScreeningKit/Sources/ScaryCatScreener/Resources` ディレクトリ内の `ScaryCatScreener.mlmodel` が利用されます。
- このモデルはビルド時にコンパイルされ、パッケージに含まれます。 