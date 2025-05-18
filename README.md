# ScaryCatScreeningKit

## プロジェクト概要

ScaryCatScreeningKitは、機械学習モデル（One-vs-Restアプローチを採用）を使用して画像を分類し、設定可能な確率の閾値に基づいてスクリーニングする関数を提供します。

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/aktrh/scary-cat-screening-kit)

## 設計

*   **`ScaryCatScreener.swift`**: 画像スクリーニングの主要なインターフェースとOne-vs-Rest分類ロジックを提供するアクターです。モデルの読み込み、画像処理、分類判断を内部で直接行います。
*   **`ScreeningDataTypes.swift`**: スクリーニング処理に関連する主要なデータ構造（`ScreeningOutput`, `ModelDetectionInfo`, `ClassResultTuple`など）を定義します。
*   **`ScreeningReport.swift`**: スクリーニング結果の詳細なレポートを生成・出力する責務を持ちます。
*   **`ScaryCatScreenerError.swift`**: パッケージ内で発生しうるエラーを定義します。

## ディレクトリ構成

```tree
.
├── SampleApp/
├── Sources/
│   ├── OvRModels/          
│   ├── ScreeningDataTypes.swift 
│   ├── ScreeningReport.swift      
│   ├── ScaryCatScreenerError.swift
│   └── ScaryCatScreener.swift
├── Package.swift
├── project.yml
└── README.md
```

## 機能詳細

### 画像スクリーニングワークフロー

1.  `ScaryCatScreener` を初期化します。この際、内部でOne-vs-Rest (OvR) 分類用のMLモデルがロードされます。
2.  設定可能な確率の閾値と共に、`screen()` メソッド経由で UIImage の配列を送信します。
3.  `ScaryCatScreener` は、ロードされたモデル群を使用して各 UIImage を処理します（内部でCGImageに変換）。
4.  内部処理の結果 (`ScreeningOutput`) には、全てのモデルの観測結果、画像を危険と判断した検出（あれば）、安全な場合の最適な「Rest」検出（あれば）が含まれます。
5.  `ScaryCatScreener` はこの出力に基づき、閾値を超える信頼度を持つ分類結果があれば UIImage を不安全としてマークします。
6.  安全な UIImage のみがアプリケーションに返却されます。
7.  オプションのログ機能（`enableLogging`）により、`ScreeningReport`を通じて詳細なスクリーニングレポートの取得が可能です。

### スクリーナー実装 (ScaryCatScreener の内部実装)

`ScaryCatScreener` は、One-vs-Rest (OvR) アプローチを直接実装しています。これは、複数の二値分類モデルを使用して画像を評価する方式です。

*   **分類アプローチ**: 複数のバイナリモデル (One-vs-Rest)。各モデルが特定の「安全でない」特徴を検出します。画像は、これらのモデルのいずれかが、指定された信頼度の閾値を超えて不適切なコンテンツを含むと判定した場合に「安全でない」と見なされます。
*   **モデル読み込み**: `ScaryCatScreener` の初期化時に、`Bundle.module` の `OvRModels` リソースディレクトリ内にある `.mlmodelc` 拡張子を持つ全てのモデルをロードします。
*   **処理アプローチ**: VisionフレームワークとCoreMLモデルを使用し、各モデルの処理はタスクグループによる並列処理が行われます。

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
    screener = try await ScaryCatScreener()
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

`screen(images:probabilityThreshold:enableLogging:)` メソッドを使用して、複数の `UIImage` を一度にスクリーニングできます。このメソッドは、安全と判断された画像の配列のみを元の順序で返します。

**パラメータ:**

-   `images`: `[UIImage]` - スクリーニング対象の画像の配列。
-   `probabilityThreshold`: `Float` (デフォルト: `0.65`)
    -   この値は `0.0` から `1.0` の範囲で指定します。
    -   いずれかのモデルが画像を「安全でない」カテゴリに属すると判定した際の信頼度 (confidence) が、この閾値以上の場合、その画像は総合的に「安全でない」と見なされます。
-   `enableLogging`: `Bool` (デフォルト: `false`)
    -   `true` を指定すると、内部処理に関する詳細ログ（CGImage変換失敗、各画像のスクリーニングレポートなど）がコンソールに出力されます。

```swift
let uiImages: [UIImage] = [/* ... スクリーニングしたい画像の配列 ... */] 

Task {
    do {
        // `screener` は上記で初期化済みの ScaryCatScreener インスタンス
        // 信頼度が70%以上のものを「安全でない」カテゴリの判定基準とし、ログ出力を有効にする例
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

### エラーハンドリング

フレームワークは `ScaryCatScreenerError` enumを通じて包括的なエラーハンドリングシステムを実装しています。このエラー型は `ScaryCatScreenerError.swift` で定義されており、 `NSError` に変換して throw されます。初期化時およびスクリーニング処理中に発生する可能性のある具体的なエラーについては、「利用方法」セクションの例も参照してください。

| エラータイプ                       | 説明                                                         |
| -------------------------------- | ------------------------------------------------------------ |
| `resourceBundleNotFound`         | MLモデルを含むリソースバンドルが見つからない場合に発生します。     |
| `modelLoadingFailed(originalError:)` | MLモデルの読み込み中にエラーが発生した場合に発生します。           |
| `modelNotFound`                  | 必要なMLモデルファイルが見つからない場合に発生します。             |
| `predictionFailed(originalError:)`   | 画像分類中にエラーが発生した場合に発生します。                   |

