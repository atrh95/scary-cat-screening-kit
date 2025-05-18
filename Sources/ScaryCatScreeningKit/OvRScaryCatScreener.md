# OvRScaryCatScreener

`ScaryCatScreeningKit` フレームワークの一部として提供される、複数の二値分類モデルを利用した画像スクリーニング機能の実装です。

## 概要

`OvRScaryCatScreener` は、内包する複数の機械学習モデル（`Resources` ディレクトリ内の `.mlmodelc` ファイル群）を利用して、与えられた画像がいずれかのモデルによって「安全でない」と判断されるかどうかを判定します。`SCSInterface` モジュールで定義された `ScaryCatScreenerProtocol` に準拠しています。

「OvR」は "One-vs-Rest" を意味し、各モデルが特定の「安全でない」特徴を検出する二値分類器として機能します。画像は、これらのモデルの**いずれか**が、指定された信頼度の閾値を超えて不適切なコンテンツを含むと判定した場合に「安全でない」と見なされます。

## セットアップ

### 1. インポート

`OvRScaryCatScreener` を利用するSwiftファイルで、必要なモジュールをインポートします。

```swift
import ScaryCatScreeningKit
```

### 2. 初期化

`OvRScaryCatScreener` の初期化は、モデルのロードに失敗する可能性があるため、エラーをスローする可能性があります (`throws`)。初期化時には `do-catch` ブロックを使用してエラーハンドリングを行うことを推奨します。

```swift
let screener: OvRScaryCatScreener

do {
    screener = try OvRScaryCatScreener()
} catch let error as NSError { // ScaryCatScreenerError.asNSError() で NSError がスローされる
    // 初期化失敗時の処理
    print("OvRScaryCatScreener の初期化に失敗しました: \(error.localizedDescription)")
    print("エラーコード: \(error.code), ドメイン: \(error.domain)")
    if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error {
        print("原因: \(underlying.localizedDescription)")
    }
    // ユーザーへのエラー通知や代替処理を実装します
}
```

初期化時にスローされる可能性のある主なエラーは `ScaryCatScreenerError` (`SCSInterface`で定義) を `asNSError()` で変換したものです。
-   `ScaryCatScreenerError.resourceBundleNotFound`: リソースバンドルまたは `Resources` ディレクトリが見つからない場合 (エラーコード: 1)。
-   `ScaryCatScreenerError.modelNotFound`: `Resources` ディレクトリ内にコンパイル済みモデルファイル (`.mlmodelc`) が一つも見つからない場合 (エラーコード: 3)。
-   `ScaryCatScreenerError.modelLoadingFailed`: いずれかのモデルファイルの読み込みに失敗した場合 (エラーコード: 2)。エラーの `userInfo[NSUnderlyingErrorKey]` に元のエラーが含まれることがあります。

## 画像のスクリーニング

スクリーニング処理 (`screen` メソッド) は非同期 (`async`) で行われ、エラーをスローする可能性があります (`throws`)。そのため、`async` コンテキスト内では `try await` を使用して呼び出す必要があります。

`screen(images:probabilityThreshold:enableLogging:)` メソッドを使用して、複数の `UIImage` を一度にスクリーニングできます。このメソッドは、安全と判断された画像の配列のみを元の順序で返します。

**パラメータ:**

-   `images`: `[UIImage]` - スクリーニング対象の画像の配列。
-   `probabilityThreshold`: `Float` (デフォルト: `0.65`)
    -   この値は `0.0` から `1.0` の範囲で指定します。
    -   いずれかのモデルが画像を「安全でない」カテゴリに属すると判定した際の信頼度 (confidence) が、この閾値以上の場合、その画像は総合的に「安全でない」と見なされます。
-   `enableLogging`: `Bool` (デフォルト: `false`)
    -   `true` を指定すると、内部処理に関する詳細ログ（CGImage変換失敗、各画像のOvRスクリーニングレポートなど）がコンソールに出力されます。

```swift
let uiImages: [UIImage] = [...] // スクリーニングしたい画像の配列

Task {
    do {
        // 信頼度が70%以上のものを「安全でない」カテゴリの判定基準とし、ログ出力を有効にする例
        // `screener` は初期化済みの OvRScaryCatScreener インスタンス
        let safeImages = try await screener.screen(
            images: uiImages, 
            probabilityThreshold: 0.70, 
            enableLogging: true
        )
        
        print("\(uiImages.count)枚中、\(safeImages.count)枚の画像が安全と判定されました。")
        
    } catch let error as NSError { // screenメソッドもScaryCatScreenerError.asNSError()でNSErrorをスローすることがある
        print("スクリーニング処理でエラーが発生しました: \(error.localizedDescription)")
        print("エラーコード: \(error.code), ドメイン: \(error.domain)")
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error {
            print("原因: \(underlying.localizedDescription)")
        }
    }
}
```
