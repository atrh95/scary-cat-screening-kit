# CatScreeningKit

Core MLモデルを使用した様々な猫の画像分類タスクを実行するためのSwift Packageです。

## Overview

`CatScreeningKit` は、Core MLモデルを利用して猫の画像を分析・分類するためのフレームワークを提供します。第一弾の実装として、「怖い猫」か「怖くない猫」かを判定する `ScaryCatScreener` クラスと、それに対応する `ScaryCatScreeningML.mlmodel` を同梱しています。(モデル名は `ScaryCatScreener` から `ScaryCatScreeningML` に変更されました)。将来的には、異なる基準で猫を分類するスクリーナーを追加することを想定した設計になっています。

## Features

- **プロトコルベースの設計:** `CatPredicting` プロトコルにより、追加のスクリーナー実装に対応。
- **`ScaryCatScreener` の実装:** `ScaryCatScreeningML.mlmodelc` を利用する初期スクリーナーを同梱。
- **`predict` メソッド:** `UIImage` を入力として分類を実行。
- **分類結果:** 予測ラベルと信頼度スコアを提供。
- **信頼度閾値:** 分類結果の最小信頼度を設定可能。
- **エラーハンドリング:** `PredictionError` enum により、失敗時のエラー情報を提供。

## Directory Structure

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

## Model Training Playground (CatScreeningML.playground)

このリポジトリには、`ScaryCatScreeningML.mlmodel` のトレーニングプロセスを実行・試行するための `CatScreeningML.playground` が含まれています。

### Playgroundの実行

1.  Xcode で `CatScreeningKit` プロジェクトを開きます。
2.  ナビゲーターから `CatScreeningML.playground` を選択して開きます。
3.  Playground が開いたら、実行ボタン（下部の ▶︎ アイコン）をクリックします。
4.  `Contents.swift` が実行され、`Sources` 内の `ScaryCatScreenerTrainer` を使用してモデルトレーニングが開始されます。
5.  トレーニングの進捗、結果（精度）、エラー、および最終的なモデルの保存先は、Playground のコンソール（デバッグエリア）に出力されます。トレーニングは非同期で行われるため、完了まで時間がかかる場合があります。

### トレーニング設定

トレーニングの挙動は `CatScreeningML.playground/Sources/ScaryCatScreenerTrainer.swift` ファイルで設定します。

- **`modelName`:** 生成される `.mlmodel` ファイルのベース名（例: `"ScaryCatScreeningML"`）。
- **`dataDirectoryName`:** トレーニングデータが含まれるディレクトリ名（`Resources` 内、例: `"ScaryCatScreenerData"`）。
- **`customOutputDirPath`:** 生成されたモデルの出力先ディレクトリ（ワークスペースルートからの相対パス、例: `"OutputModels"`）。
- **`resourcesDirectoryPath`:** トレーニングデータを含む `Resources` ディレクトリの場所（通常は変更不要）。
- **トレーニングパラメータ:** `executeTrainingCore` メソッド内の `MLImageClassifier.ModelParameters` で、データ拡張 (`augmentation`) や最大反復回数 (`maxIterations`) などを設定できます。

### トレーニングデータ

トレーニング用の画像データは `CatScreeningML.playground/Resources/` 内に配置します。
- `ScaryCatScreenerTrainer` は現在 `ScaryCatScreenerData` ディレクトリを参照しています。
- このディレクトリ内に、分類したいクラス（例: `Scary`, `Not Scary`）と同じ名前のサブディレクトリを作成し、それぞれの画像を配置します。

### 出力モデル

トレーニングが成功すると、設定された `customOutputDirPath`（デフォルトでは `<ワークスペースルート>/OutputModels`）に `.mlmodel` ファイルが生成されます。同名のファイルが既に存在する場合は、ファイル名に連番（例: `_1`, `_2`）が付与されます。

生成されたモデルを `CatScreeningKit` で使用するには、`CatScreeningKit/Sources/ScaryCatScreener/Resource/` ディレクトリにコピー（または移動）し、必要に応じてファイル名をリネームしてください。

### 精度改善のヒント

モデルの精度を改善するための一般的なヒントについては、`CatScreeningML.playground/Sources/AccuracyImprovementTips.md` を参照してください。

## 設計方針

`CatScreeningKit` は、テスト容易性と将来の拡張性を高めるために、プロトコル (`CatPredicting`) ベースの設計を採用しています。

### プロトコル (`CatPredicting`)

主要な機能である画像予測は `CatPredicting` プロトコルによって抽象化されています。このプロトコルは、画像を受け取り、分類結果（ラベルと信頼度）またはエラーを非同期で返す `predict` メソッドを定義します。

クライアントコードは、具体的なスクリーナー実装クラス（例: `ScaryCatScreener`）に直接依存するのではなく、この `CatPredicting` プロトコルに依存することが強く推奨されます。これにより、以下のようなメリットが得られます:

*   **テスト容易性:** ユニットテスト時に、実際の Core ML モデルを必要としない軽量なモックオブジェクトを依存性注入できます。
*   **柔軟性と拡張性:** 将来的に新しい分類基準を持つスクリーナーを追加する場合、それらも `CatPredicting` プロトコルに準拠させるだけで、既存のクライアントコードは最小限の変更で新しいスクリーナーを利用できます。

## 利用可能なスクリーナー

現在、以下のスクリーナーが `CatScreeningKit` に含まれています。

- **ScaryCatScreener:** 猫の画像が「怖い」か「怖くない」かを分類します。
    - (詳細ドキュメントは現在準備中です)

今後、他の分類基準を持つスクリーナーが追加される可能性があります。

## Error Handling

`predict` メソッドは `Result<(label: String, confidence: Float), PredictionError>` を返します。失敗時には `PredictionError` で詳細なエラー内容を示します。 