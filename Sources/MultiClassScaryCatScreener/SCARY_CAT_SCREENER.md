# ScaryCatScreener

`CatScreeningKit` フレームワークの一部として提供される、猫画像スクリーニング機能の実装です。

## 概要

`ScaryCatScreener` は、内包する機械学習モデル（`ScaryCatScreeningML.mlmodel`）を利用して、与えられた猫の画像が特定のカテゴリ（例："怖い猫"）に該当するかどうかを判定します。

## セットアップ

### 1. インポート

`ScaryCatScreener` を利用するSwiftファイルで、`CatScreeningKit` モジュールをインポートします。

```swift
import CatScreeningKit
```

### 2. 初期化

`ScaryCatScreener` の初期化は、モデルのロードに失敗する可能性があるため、失敗可能なイニシャライザ（`init?`）として提供されています。初期化時には `do-catch` ブロックを使用するか、`try?` を用いてオプショナルとしてインスタンスを取得し、エラーハンドリングを行うことを推奨します。

```swift
let screener: ScaryCatScreener?

do {
    screener = try ScaryCatScreener()
    // screener が正常に初期化された場合の処理
} catch {
    // 初期化失敗時の処理
    print("ScaryCatScreener の初期化に失敗しました: \(error.localizedDescription)")
    screener = nil
    // 必要に応じて、ユーザーへのエラー通知や代替処理を実装します
}
```

または、`guard` 文と `try?` を使用する簡潔な方法もあります。

```swift
guard let screener = try? ScaryCatScreener() else {
    // 初期化失敗時の処理
    fatalError("ScaryCatScreener の初期化に失敗しました。") // または、より丁寧なエラーハンドリング
}
// screener を使用
```

## 画像のスクリーニング

スクリーニング処理は非同期で行われ、エラーをスローする可能性があります。そのため、`async` コンテキスト内で `try await` を使用して呼び出す必要があります。

### 単一画像のスクリーニング

`screen(image:)` メソッドを使用して、単一の `UIImage` をスクリーニングします。

```swift
// `uiImage` はスクリーニング対象の UIImage インスタンス
// `screener` は初期化済みの ScaryCatScreener インスタンス

guard let screener = self.screener else {
    print("スクリーナーが初期化されていません。")
    return
}

guard let uiImage = UIImage(named: "cat_image") else {
    print("画像が見つかりません。")
    return
}

Task {
    do {
        let report = try await screener.screen(image: uiImage)
        
        if let detection = report.decisiveDetection {
            print("判定結果: \(detection.identifier), 信頼度: \(detection.confidence)")
            // "怖い猫"と判定された場合の処理など
        } else {
            print("特に問題のあるカテゴリには分類されませんでした（安全と判断）。")
        }
        
        // 全ての分類結果を確認する場合
        print("--- 全分類結果 ---")
        for classification in report.allClassifications {
            print("  - \(classification.identifier): \(classification.confidence)")
        }
        
    } catch let screenerError as ScaryCatScreenerError {
        // ScaryCatScreenerError 固有のエラー処理
        print("スクリーニング処理でエラーが発生しました: \(screenerError.localizedDescription)")
    } catch {
        // その他の予期せぬエラー処理
        print("スクリーニング中に予期せぬエラーが発生しました: \(error.localizedDescription)")
    }
}
```

### 複数画像のスクリーニング（バッチ処理）

`screen(images:probabilityThreshold:enableLogging:)` メソッドを使用して、複数の `UIImage` を一度にスクリーニングできます。このメソッドは、指定した信頼度の閾値（`probabilityThreshold`）を超えた場合にのみ「安全でない」と判定された画像をフィルタリングし、安全と判断された画像の配列を返します。オプションで `enableLogging` を `true` に設定すると、処理中の詳細なログがコンソールに出力されます（デフォルトは `false` でログ出力なし）。

```swift
// `uiImages` はスクリーニング対象の [UIImage] 配列
// `screener` は初期化済みの ScaryCatScreener インスタンス

guard let screener = self.screener else {
    print("スクリーナーが初期化されていません。")
    return
}

let uiImages: [UIImage] = [...] // スクリーニングしたい画像の配列

Task {
    do {
        // 信頼度が65%以上のものを危険と判定し、ログ出力を有効にする例
        let safeImages = try await screener.screen(images: uiImages, probabilityThreshold: 0.65, enableLogging: true) 
        
        print("\(uiImages.count)枚中、\(safeImages.count)枚の画像が安全と判定されました。")
        // safeImages を使ってUIを更新するなどの処理
        
    } catch let screenerError as ScaryCatScreenerError {
        print("スクリーニング処理でエラーが発生しました: \(screenerError.localizedDescription)")
    } catch {
        print("スクリーニング中に予期せぬエラーが発生しました: \(error.localizedDescription)")
    }
}
```

`probabilityThreshold` パラメータ:
- この値は `0.0` から `1.0` の範囲で指定します。
- モデルが特定のカテゴリ（例: "怖い猫"）に属すると判定した際の信頼度（confidence）が、この閾値以上の場合、その画像は「安全でない可能性が高い」と見なされます。
- `screen(images:probabilityThreshold:enableLogging:)` メソッドは、この閾値に基づいてフィルタリングを行い、閾値未満の信頼度でしか問題のあるカテゴリに分類されなかった画像、または全く問題のあるカテゴリに分類されなかった画像のみを「安全な画像」として返します。

`enableLogging` パラメータ (Optional):
- 型: `Bool`
- デフォルト値: `false`
- `true` を指定すると、`ScaryCatScreener` の内部処理に関する詳細ログ（各画像のCGImage変換試行、Visionリクエストの実行状況、個別のスクリーニングレポートなど）がコンソールに出力されます。
- デバッグ時や詳細な動作確認を行いたい場合に利用します。通常運用時は `false`（デフォルト）のままにしておくことで、コンソール出力を抑制できます。

## エラーハンドリング

`ScaryCatScreener` の利用時には、主に以下のエラーを考慮する必要があります。

-   **初期化時のエラー**: モデルファイルのロード失敗など。`ScaryCatScreenerError.modelLoadingFailed` などがスローされる可能性があります。
-   **スクリーニング時のエラー**: 画像処理中の問題や、モデルによる予測実行時の問題など。`ScaryCatScreenerError` の各ケース（例: `predictionFailed`, `featureExtractionFailed`）がスローされる可能性があります。

各エラーの詳細は、`ScaryCatScreenerError` の定義を参照してください。

## 使用モデル

-   `CatScreeningKit/Sources/ScaryCatScreener/Resources` ディレクトリ内に配置されている `ScaryCatScreeningML.mlmodel` が内部的に利用されます。
-   このモデルは、ライブラリのビルド時にコンパイルされ、フレームワーク内に同梱されます。 