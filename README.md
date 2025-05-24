# ScaryCatScreeningKit

## プロジェクト概要

ScaryCatScreeningKitは、機械学習モデル（One-vs-Restアプローチを採用）を使用して画像を分類し、設定可能な確率の閾値に基づいてスクリーニングを行う機能を提供するライブラリです。

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/aktrh/scary-cat-screening-kit)

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

## 機能詳細

### 画像スクリーニングワークフロー

1.  `ScaryCatScreener` を初期化します。この際、内部でOne-vs-Rest (OvR) 分類用のMLモデルがロードされます。
2.  設定可能な確率の閾値と共に、`screen()` メソッド経由で CGImage の配列を送信します。
3.  `ScaryCatScreener` は、ロードされたモデル群を使用して各 CGImage を処理します。
4.  内部処理の結果 (`SCScreeningResults`) には、全ての画像のスクリーニング結果が含まれます。各結果は `IndividualScreeningResult` として以下の情報を持ちます：
    - `index`: 入力画像配列での位置（0から始まる）
    - `cgImage`: 元の画像
    - `scaryFeatures`: 検出された怖い特徴の配列（各要素は `featureName` と `confidence` のペア）
    - `isSafe`: 安全と判断されたかどうか（`scaryFeatures` が空の場合に `true`）
5.  `SCScreeningResults` は以下の便利なプロパティを提供します：
    - `results`: 入力画像と同じ順序での各画像のスクリーニング結果の配列
    - `safeImages`: 安全と判断された画像の配列（`isSafe` が `true` の画像のみ）
    - `scaryFeatures`: 検出された怖い特徴ごとの画像と信頼度のマップ（キーは特徴名、値は `(image, confidence)` の配列）
6.  オプションのログ機能（`enableLogging`）により、`printDetailedReport()`を通じて詳細なスクリーニングレポートの取得が可能です。レポートには以下が含まれます：
    - 各画像のスクリーニング結果（安全/危険の状態と検出された特徴）
    - サマリー（安全な画像の数と検出された危険な特徴の種類数）

### スクリーナー実装 (ScaryCatScreener の内部実装)

`ScaryCatScreener` は、One-vs-Rest (OvR) アプローチを直接実装しています。これは、複数の二値分類モデルを使用して画像を評価する方式です。

*   **分類アプローチ**: 複数のバイナリモデル (One-vs-Rest)。各モデルが特定の「安全でない」特徴を検出します。画像は、これらのモデルのいずれかが、指定された信頼度の閾値を超えて不適切なコンテンツを含むと判定した場合に「安全でない」と見なされます。
*   **モデル読み込み**: `ScaryCatScreener` の初期化時に、`Bundle.module` の `OvRModels` リソースディレクトリ内にある `.mlmodelc` 拡張子を持つ全てのモデルをロードします。
*   **処理アプローチ**: VisionフレームワークとCoreMLモデルを使用し、各モデルの処理はタスクグループによる並列処理が行われます。
*   **環境最適化**: シミュレータ環境ではCPUのみを使用し、実機環境では全計算ユニットを使用するように最適化されています。

### 利用方法 (ScaryCatScreener のセットアップと使用)

#### 1. インポート

`ScaryCatScreener` を利用するSwiftファイルで、必要なモジュールをインポートします。

```swift
import ScaryCatScreeningKit
```

#### 2. 初期化

`ScaryCatScreener` の初期化は、モデルのロードに失敗する可能性があるため、エラーをスローする可能性があります (`throws`)。初期化時には `do-catch` ブロックを使用してエラーハンドリングを行うことを推奨します。

```swift
let screener: ScaryCatScreener

do {
    screener = try await ScaryCatScreener(enableLogging: true) // ログ出力を有効にする例
} catch let error as NSError { // ScaryCatScreenerError.asNSError() で NSError がスローされる
    // 初期化失敗時の処理
    print("ScaryCatScreener の初期化に失敗しました: \(error.localizedDescription)")
    print("エラーコード: \(error.code), ドメイン: \(error.domain)")
    if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error {
        print("原因: \(underlying.localizedDescription)")
    }
    // ユーザーへのエラー通知や代替処理を実装します
}
```

初期化時にスローされる可能性のある主なエラーは `ScaryCatScreenerError` を `asNSError()` で変換したものです（エラー定義は `ScaryCatScreenerError.swift` を参照）。考えられる主なエラーは以下の通りです:
-   `ScaryCatScreenerError.resourceBundleNotFound`: リソースバンドルまたは `OvRModels` ディレクトリが見つからない場合。
-   `ScaryCatScreenerError.modelNotFound`: `OvRModels` ディレクトリ内にコンパイル済みモデルファイル (`.mlmodelc`) が一つも見つからない場合。
-   `ScaryCatScreenerError.modelLoadingFailed`: いずれかのモデルファイルの読み込みに失敗した場合。エラーの `userInfo[NSUnderlyingErrorKey]` に元のエラーが含まれることがあります。

#### 3. 画像のスクリーニング

スクリーニング処理 (`screen` メソッド) は非同期 (`async`) で行われ、エラーをスローする可能性があります (`throws`)。そのため、`async` コンテキスト内では `try await` を使用して呼び出す必要があります。

`screen(cgImages:probabilityThreshold:enableLogging:)` メソッドを使用して、複数の `CGImage` を一度にスクリーニングできます。このメソッドは、`SCScreeningResults` オブジェクトを返し、これには全ての画像のスクリーニング結果が含まれます。

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

### エラーハンドリング

フレームワークは `ScaryCatScreenerError` enumを通じて包括的なエラーハンドリングシステムを実装しています。このエラー型は `ScaryCatScreenerError.swift` で定義されており、 `NSError` に変換して throw されます。初期化時およびスクリーニング処理中に発生する可能性のある具体的なエラーについては、「利用方法」セクションの例も参照してください。

| エラータイプ                       | 説明                                                         |
| -------------------------------- | ------------------------------------------------------------ |
| `resourceBundleNotFound`         | MLモデルを含むリソースバンドルが見つからない場合に発生します。     |
| `modelLoadingFailed(originalError:)` | MLモデルの読み込み中にエラーが発生した場合に発生します。           |
| `modelNotFound`                  | 必要なMLモデルファイルが見つからない場合に発生します。             |
| `predictionFailed(originalError:)`   | 画像分類中にエラーが発生した場合に発生します。                   |

