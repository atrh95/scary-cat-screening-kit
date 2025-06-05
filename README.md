# ScaryCatScreeningKit

## プロジェクト概要

ScaryCatScreeningKitは、One-vs-Restアプローチを採用した機械学習モデルを使用して猫の画像のスクリーニングを行う機能を提供します。

## 設計

*   **`ScaryCatScreener.swift`**: MLModelを読み込み、One-vs-Rest分類ロジックを用いた画像分類を行います。
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
var screener: ScaryCatScreener

do {
    screener = try await ScaryCatScreener(enableLogging: true) // 初期化時のログ出力を有効にする例
} catch let error as NSError { // ScaryCatScreenerError.asNSError()
    print("ScaryCatScreener の初期化に失敗しました: \(error.localizedDescription)")
    print("エラーコード: \(error.code), ドメイン: \(error.domain)")
    if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error {
        print("原因: \(underlying.localizedDescription)")
    }
}
```

#### 3. 画像のスクリーニング

`screen` メソッド は非同期で行われ、エラーをスローする可能性があります。そのため、`async` コンテキスト内では `try await` を使用して呼び出す必要があります。

**パラメータ:**

-   `imageDataList`: `[Data]` - スクリーニング対象の画像データの配列。
-   `probabilityThreshold`: `Float` (デフォルト: `0.95`)
    -   この値は `0.0` から `1.0` の範囲で指定します。
    -   いずれかのモデルが画像を「安全でない」カテゴリに属すると判定した際の信頼度 (confidence) が、この閾値以上の場合、その画像は総合的に「安全でない」と見なされます。
-   `enableLogging`: `Bool` (デフォルト: `false`)
    -   `true` を指定すると、内部処理に関する詳細ログ（各画像のスクリーニングレポートなど）がコンソールに出力されます。

**注意点:**
- "rest"と"safe"は安全と考慮する要素として扱われ、信頼度の収集から除外されます。
- mouth_openのみが検出された場合、OvOモデル（ScaryCatScreeningML_OvO_mouth_open_vs_safe_v1.mlmodelc）による追加の検証が行われます。

```swift
let imageDataList: [Data] = [/* ... スクリーニングしたい画像データの配列 ... */] 

Task {
    do {
        // `screener` は上記で初期化済みの ScaryCatScreener インスタンス
        // 信頼度が95%以上のものを「安全でない」カテゴリの判定基準とし、ログ出力を有効にする例
        let screeningResults = try await screener.screen(
            imageDataList: imageDataList, 
            probabilityThreshold: 0.95, 
            enableLogging: true
        )
        
        // 安全な画像データのみを取得
        let safeImageData: [Data] = screeningResults.safeResults.map(\.imageData)
        
        // 危険な画像データのみを取得
        let unsafeImageData: [Data] = screeningResults.unsafeResults.map(\.imageData)
        
        // レポートを出力
        print(screeningResults.generateDetailedReport())
        
    } catch let error as NSError {
        print("スクリーニング処理でエラーが発生しました: \(error.localizedDescription)")
        print("エラーコード: \(error.code), ドメイン: \(error.domain)")
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error {
            print("原因: \(underlying.localizedDescription)")
        }
    }
}
```

`screen(imageDataList:probabilityThreshold:enableLogging:)` メソッドは`SCSOverallScreeningResults`を返します。この構造体は、スクリーニング結果を管理し、安全な画像と危険な画像へのアクセスを提供します。

主要な構造は以下の通りです

```swift
/// 個別の画像のスクリーニング結果
public struct SCSIndividualScreeningResult: Identifiable, Sendable {
    public var id = UUID()
    public var imageData: Data
    public var confidences: [String: Float]
    public var probabilityThreshold: Float
    public var originalIndex: Int  // 元の配列中のインデックスを保持
    
    public var isSafe: Bool {
        !confidences.values.contains { $0 >= probabilityThreshold }
    }
}

/// 複数のスクリーニング結果を管理する構造体
public struct SCSOverallScreeningResults: Sendable {
    public var results: [SCSIndividualScreeningResult]
    
    public var safeResults: [SCSIndividualScreeningResult] {
        results.filter { $0.isSafe }
    }
    
    public var unsafeResults: [SCSIndividualScreeningResult] {
        results.filter { !$0.isSafe }
    }
}
```

完全な実装は [Sources/ScreeningDataTypes.swift](Sources/ScreeningDataTypes.swift) を参照してください。

### エラーハンドリング

フレームワークは `ScaryCatScreenerError` enumを通じてエラーハンドリングシステムを実装しています。このエラー型は `ScaryCatScreenerError.swift` で定義されており、 `NSError` に変換して throw されます。

| エラータイプ                       | 説明                                                         |
| -------------------------------- | ------------------------------------------------------------ |
| `resourceBundleNotFound`         | MLモデルを含むリソースバンドルが見つからない場合に発生します。     |
| `modelLoadingFailed(originalError:)` | MLモデルの読み込み中にエラーが発生した場合に発生します。           |
| `modelNotFound`                  | 必要なMLモデルファイルが見つからない場合に発生します。             |
| `predictionFailed(originalError:)`   | 画像分類中にエラーが発生した場合に発生します。                   |

