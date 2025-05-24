# ScaryCatScreeningKit

## プロジェクト概要

ScaryCatScreeningKitは、機械学習モデル（One-vs-Restアプローチを採用）を使用して画像を分類し、設定可能な確率の閾値に基づいてスクリーニングを行う機能を提供するライブラリです。

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/aktrh/scary-cat-screening-kit)

## 必要条件

- iOS 17.0以上
- Swift 6.0以上
- Xcode 15.0以上

## 設計

*   **`ScaryCatScreener.swift`**: 画像スクリーニングの主要なインターフェースとOne-vs-Rest分類ロジックを提供します。モデルの読み込み、画像処理を行います。
*   **`ScreeningDataTypes.swift`**: スクリーニングに関連する主要なデータ構造を定義します。
*   **`ScaryCatScreenerError.swift`**: 発生しうるエラーを定義します。

## ディレクトリ構成

```tree
.
├── SampleApp/
├── Sources/
│   ├── OvRModels/          
│   ├── ScreeningDataTypes.swift  
│   ├── ScaryCatScreenerError.swift
│   └── ScaryCatScreener.swift
├── Package.swift
├── project.yml
└── README.md
```

`SampleApp`の動作確認は、シミュレータではなくiPhone 16などの実機で行うことを推奨します。シミュレータ環境ではNeural Engineなどの計算ユニットが使用できないため、スクリーニングの精度と速度が低下します。

### 利用方法

#### 1. インポート

`ScaryCatScreener` を利用するSwiftファイルで、必要なモジュールをインポートします。

```swift
import ScaryCatScreeningKit
```

#### 2. 初期化

`ScaryCatScreener` の初期化は、モデルのロードに失敗する可能性があるため、エラーをスローする可能性があるため、 `do-catch` ブロックを使用してエラーハンドリングを行うことを推奨します。

```swift
let screener: ScaryCatScreener

do {
    screener = try await ScaryCatScreener(enableLogging: true) // ログ出力を有効にする例
} catch let error as NSError { // ScaryCatScreenerError.asNSError()
    // 初期化失敗時の処理
    print("ScaryCatScreener の初期化に失敗しました: \(error.localizedDescription)")
    print("エラーコード: \(error.code), ドメイン: \(error.domain)")
    if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error {
        print("原因: \(underlying.localizedDescription)")
    }
}
```

#### 3. 画像のスクリーニング

スクリーニング処理 (`screen` メソッド) は非同期 (`async`) で行われ、エラーをスローする可能性があります (`throws`)。そのため、`async` コンテキスト内では `try await` を使用して呼び出す必要があります。

**パラメータ:**

-   `cgImages`: `[CGImage]` - スクリーニング対象の画像の配列。
-   `probabilityThreshold`: `Float` (デフォルト: `0.85`)
    -   この値は `0.0` から `1.0` の範囲で指定します。
    -   いずれかのモデルが画像を「安全でない」カテゴリに属すると判定した際の信頼度 (confidence) が、この閾値以上の場合、その画像は総合的に「安全でない」と見なされます。
-   `enableLogging`: `Bool` (デフォルト: `false`)
    -   `true` を指定すると、内部処理に関する詳細ログ（各画像のスクリーニングレポートなど）がコンソールに出力されます。

```swift
let cgImages: [CGImage] = [/* ... スクリーニングしたい画像の配列 ... */] 

Task {
    do {
        // `screener` は上記で初期化済みの ScaryCatScreener インスタンス
        // 信頼度が85%以上のものを「安全でない」カテゴリの判定基準とし、ログ出力を有効にする例
        let results = try await screener.screen(
            cgImages: cgImages, 
            probabilityThreshold: 0.85, 
            enableLogging: true
        )
        
        // 安全な画像のみを取得
        let safeImages = results.safeImages
        
        // 検出された怖い特徴ごとの画像と信頼度を取得
        let scaryFeatures = results.scaryFeatures
        
        // 詳細なレポートを出力
        results.printDetailedReport()
        
    } catch let error as NSError { // screenメソッドもScaryCatScreenerError.asNSError()でNSErrorをスローすることがある
        print("スクリーニング処理でエラーが発生しました: \(error.localizedDescription)")
        print("エラーコード: \(error.code), ドメイン: \(error.domain)")
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error {
            print("原因: \(underlying.localizedDescription)")
        }
    }
}
```

`screen(cgImages:probabilityThreshold:enableLogging:)` メソッドを使用して、複数の `CGImage` を一度にスクリーニングできます。このメソッドは、`SCScreeningResults` オブジェクトを返し、これには全ての画像のスクリーニング結果が含まれます。

```swift
public struct SCScreeningResults: Sendable {
    /// 入力画像と同じ順序での各画像のスクリーニング結果
    public let results: [IndividualScreeningResult]
    
    /// 安全と判断された画像の配列
    public var safeImages: [CGImage] {
        results.filter { $0.isSafe }.map { $0.cgImage }
    }
    
    /// 検出された怖い特徴ごとの画像と信頼度のマップ
    public var scaryFeatures: [String: [(image: CGImage, confidence: Float)]] {
        Dictionary(
            grouping: results.filter { !$0.isSafe }.flatMap { result in
                result.scaryFeatures.map { feature in
                    (feature.featureName, (image: result.cgImage, confidence: feature.confidence))
                }
            },
            by: { $0.0 }
        ).mapValues { $0.map { $1 } }
    }
}

/// 検出された怖い特徴（クラス名と信頼度のペア）
public typealias DetectedScaryFeature = (featureName: String, confidence: Float)

/// 個別の画像のスクリーニング結果
public struct IndividualScreeningResult {
    /// 画像のインデックス
    public let index: Int
    /// スクリーニング対象の画像
    public let cgImage: CGImage
    /// 検出された怖い特徴の配列
    public let scaryFeatures: [DetectedScaryFeature]
    
    /// 安全と判断されたかどうか
    public var isSafe: Bool {
        scaryFeatures.isEmpty
    }
}
```

### エラーハンドリング

フレームワークは `ScaryCatScreenerError` enumを通じて包括的なエラーハンドリングシステムを実装しています。このエラー型は `ScaryCatScreenerError.swift` で定義されており、 `NSError` に変換して throw されます。初期化時およびスクリーニング処理中に発生する可能性のある具体的なエラーについては、「利用方法」セクションの例も参照してください。

| エラータイプ                       | 説明                                                         |
| -------------------------------- | ------------------------------------------------------------ |
| `resourceBundleNotFound`         | MLモデルを含むリソースバンドルが見つからない場合に発生します。     |
| `modelLoadingFailed(originalError:)` | MLモデルの読み込み中にエラーが発生した場合に発生します。           |
| `modelNotFound`                  | 必要なMLモデルファイルが見つからない場合に発生します。             |
| `predictionFailed(originalError:)`   | 画像分類中にエラーが発生した場合に発生します。                   |

