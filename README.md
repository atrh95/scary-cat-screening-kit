# CatScreeningKit

Core MLモデルを使用した様々な猫の画像分類タスクを実行するためのSwift Packageです。

## 概要

`CatScreeningKit` は、Core MLモデルを利用して猫の画像を分析・分類するためのフレームワークを提供します。第一弾の実装として、「怖い猫」か「怖くない猫」かを判定する `ScaryCatScreener` を同梱しています。このスクリーナーは `ScaryCatScreeningML.mlmodel` を利用します。フレームワークは将来的に、異なる基準で猫を分類するスクリーナーを追加することを想定した、拡張性の高い設計になっています。

主な機能として、`CatScreenerProtocol` に基づくプロトコル指向設計を採用しており、テスト容易性と拡張性を高めています。初期実装の `ScaryCatScreener` は、`UIImage` を入力として受け取り、分類ラベルと信頼度スコアを非同期で返す `screen` メソッドを提供します。分類の最小信頼度は設定可能で、エラー発生時には `PredictionError` enum で詳細情報を提供します。

## ディレクトリ構成

```
.
├── CatScreeningKit/
│   ├── Sources/
│   │   └── ScaryCatScreener/
│   │       ├── Resource/
│   │       │   └── ScaryCatScreeningML.mlmodel
│   │       └── ScaryCatScreener.swift
│   ├── Tests/
│   │   └── ScaryCatScreenerTests/
│   │       ├── NotScary/
│   │       ├── Scary/
│   │       └── ScaryCatScreenerTests.swift
│   └── Package.swift
│
├── CatScreeningML.playground/
│   ├── Contents.swift
│   ├── Resources/
│   │   └── ScaryCatScreenerData/
│   │       ├── Not Scary/
│   │       └── Scary/
│   └── Sources/
│       ├── ScaryCatScreenerTrainer.swift
│       ├── ScreeningTrainerProtocol.swift
│       └── AccuracyImprovementTips.md
├── OutputModels/
│   └── ScaryCatScreeningML/
│
├── .gitignore
└── README.md
```

## モデルトレーニング用Playground (`CatScreeningML.playground`)

リポジトリには `ScaryCatScreeningML.mlmodel` のトレーニングを実行・試行するための `CatScreeningML.playground` が含まれています。

**Playgroundの実行:** Xcodeで `CatScreeningKit` プロジェクトを開き、ナビゲーターから `CatScreeningML.playground` を選択して実行（▶︎）します。`Contents.swift` が `Sources` 内の `ScaryCatScreenerTrainer` を使用してトレーニングを開始します。進捗、結果、エラー、モデル保存先はコンソールに出力されます（非同期処理のため完了まで時間がかかる場合があります）。

**トレーニング設定:** 設定は `CatScreeningML.playground/Sources/ScaryCatScreenerTrainer.swift` で行います。`modelName`, `dataDirectoryName`, `customOutputDirPath`, `resourcesDirectoryPath` を調整できます。また、`executeTrainingCore` メソッド内の `MLImageClassifier.ModelParameters` でデータ拡張 (`augmentation`) や最大反復回数 (`maxIterations`) などのトレーニングパラメータも設定可能です。

**トレーニングデータ:** 画像データは `CatScreeningML.playground/Resources/ScaryCatScreenerData/` 内に配置します。クラス名（例: `Scary`, `Not Scary`）と同じ名前のサブディレクトリを作成し、画像を入れます。

**出力モデル:** トレーニングが成功すると、`customOutputDirPath`（デフォルト: `OutputModels/`）に `.mlmodel` ファイルが生成されます（同名ファイル存在時は連番付与）。生成されたモデルを `CatScreeningKit` で使用するには、`CatScreeningKit/Sources/ScaryCatScreener/Resource/` にコピーし、必要に応じてリネームしてください。

**精度改善:** モデル精度改善のヒントは [AccuracyImprovementTips.md](CatScreeningML.playground/Sources/AccuracyImprovementTips.md) を参照してください。

## 設計方針 (`CatScreenerProtocol`)

`CatScreeningKit` の中心となるのは `CatScreenerProtocol` です。これは画像を受け取り、分類結果またはエラーを非同期で返す `screen` メソッドを定義します。クライアントコードは具体的な実装クラス（例: `ScaryCatScreener`）ではなく、このプロトコルに依存することが推奨されます。これにより、テスト時にモックオブジェクトを容易に注入でき、将来新しいスクリーナーを追加する際も、既存コードへの影響を最小限に抑えられます。

## 利用可能なスクリーナー

- **ScaryCatScreener:** 猫の画像が「怖い」か「怖くない」かを分類します。
    - [詳細ドキュメント](CatScreeningKit/Sources/ScaryCatScreener/SCARY_CAT_SCREENER.md)

今後、他の分類基準を持つスクリーナーが追加される可能性があります。

## エラーハンドリング

`screen` メソッドは `Result<(label: String, confidence: Float), PredictionError>` を返します。失敗時には `PredictionError` で詳細なエラー内容を示します。 