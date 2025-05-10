# MultiClassScaryCatScreener

`ScaryCatScreeningKit` フレームワークの一部として提供される、複数クラス対応の画像スクリーニング機能の実装です。

## 概要

`MultiClassScaryCatScreener` は、内包する機械学習モデル（`ScaryCatScreeningML.mlmodelc`）を利用して、与えられた画像が複数の定義済みカテゴリのいずれかに該当するかどうかを判定します。`SCSInterface` モジュールで定義された `ScaryCatScreenerProcotol` (*注: `ScaryCatScreenerInterface` の意図である可能性があります*) プロトコルに準拠しています。

## セットアップ

### 1. インポート

`MultiClassScaryCatScreener` を利用するSwiftファイルで、必要なモジュールをインポートします。

```swift
import MultiClassScaryCatScreener
```

### 2. 初期化

`MultiClassScaryCatScreener` の初期化は、モデルのロードに失敗する可能性があるため、エラーをスローする可能性があります (`throws`)。初期化時には `do-catch` ブロックを使用してエラーハンドリングを行うことを推奨します。

```swift
let screener: MultiClassScaryCatScreener

do {
    screener = try MultiClassScaryCatScreener()
    // screener が正常に初期化された場合の処理
} catch let error as NSError { // ScaryCatScreenerError.asNSError() で NSError がスローされる
    // 初期化失敗時の処理
    print("MultiClassScaryCatScreener の初期化に失敗しました: \(error.localizedDescription)")
    print("エラーコード: \(error.code), ドメイン: \(error.domain)")
    if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error {
        print("原因: \(underlying.localizedDescription)")
    }
    // ユーザーへのエラー通知や代替処理を実装します
}
```

初期化時にスローされる可能性のある主なエラーは `ScaryCatScreenerError` を `asNSError()` で変換したものです。
-   `ScaryCatScreenerError.resourceBundleNotFound`: リソースバンドルが見つからない場合 (エラーコード: 1)。
-   `ScaryCatScreenerError.modelLoadingFailed`: モデルファイルの読み込みに失敗した場合 (エラーコード: 2)。

## 画像のスクリーニング

スクリーニング処理 (`screen` メソッド) は非同期 (`async`) で行われ、エラーをスローする可能性があります (`throws`)。そのため、`async` コンテキスト内では `try await` を使用して呼び出す必要があります。

`screen(images:probabilityThreshold:enableLogging:)` メソッドを使用して、複数の `UIImage` を一度にスクリーニングできます。このメソッドは、安全と判断された画像の配列のみを元の順序で返します。

**パラメータ:**

-   `images`: `[UIImage]` - スクリーニング対象の画像の配列。
-   `probabilityThreshold`: `Float` (デフォルト: `0.65`)
    -   この値は `0.0` から `1.0` の範囲で指定します。
    -   モデルが「safe」以外のカテゴリに属すると判定した際の信頼度 (confidence) が、この閾値以上の場合、その画像は「安全でない」と見なされます。
-   `enableLogging`: `Bool` (デフォルト: `false`)
    -   `true` を指定すると、内部処理に関する詳細ログ（CGImage変換失敗、各画像のスクリーニングレポートなど）がコンソールに出力されます。

```swift
let uiImages: [UIImage] = [...] // スクリーニングしたい画像の配列

Task {
    do {
        // 信頼度が65%以上のものを「安全でない」カテゴリの判定基準とし、ログ出力を有効にする例
        // `screener` は初期化済みの MultiClassScaryCatScreener インスタンス
        let safeImages = try await screener.screen(
            images: uiImages, 
            // 信頼度0.65以上の場合に画像を対応するカテゴリに分類し、弾く
            probabilityThreshold: 0.65, 
            enableLogging: true
        ) 
        
        print("\(uiImages.count)枚中、\(safeImages.count)枚の画像が安全と判定されました。")
        // safeImages を使ってUIを更新するなどの処理
        
    } catch let error as NSError {
        print("スクリーニング処理でエラーが発生しました: \(error.localizedDescription)")
        print("エラーコード: \(error.code), ドメイン: \(error.domain)")
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error {
            print("原因: \(underlying.localizedDescription)")
        }
    }
}
```
