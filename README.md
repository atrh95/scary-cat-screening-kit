# CatScreeningKit

Core MLモデルを使用した様々な猫の画像分類タスクを実行するためのSwift Packageです。

## Overview

`CatScreeningKit` は、Core MLモデルを利用して猫の画像を分析・分類するためのフレームワークを提供します。第一弾の実装として、「怖い猫」か「怖くない猫」かを判定する `ScaryCatScreener` クラスと、それに対応する `ScaryCatScreener.mlmodel` を同梱しています。将来的には、異なる基準で猫を分類するスクリーナーを追加することを想定した設計になっています。

## Features

- **柔軟な設計:** `CatPredicting` プロトコルにより、様々な分類モデルをラップするスクリーナーを追加可能。
- **初期実装:** `ScaryCatScreener.mlmodelc` を使用する `ScaryCatScreener` を提供。
- **簡単な利用:** `UIImage` を分類する `predict` メソッドを提供。
- **詳細な結果:** 予測ラベルと信頼度スコアを返します。
- **信頼度制御:** 最小信頼度の閾値を設定可能です。
- **堅牢なエラー処理:** 失敗時の詳細なエラー情報を提供する `PredictionError` enumを定義。

## Directory Structure

```
.
├── CatScreeningKit/
│   ├── Sources/
│   │   └── ScaryCatScreener/
│   │       ├── Resource/
│   │       │   └── ScaryCatScreener.mlmodel
│   │       └── ScaryCatScreener.swift
│   ├── Tests/
│   │   └── ScaryCatScreenerTests/
│   │       ├── NotScary/
│   │       ├── Scary/
│   │       └── ScaryCatScreenerTests.swift
│   └── Package.swift
├── CatScreeningML.playground/
│   ├── CAT_SCREENING_ML.md
│   ├── Contents.swift
│   ├── Sources/
│   │   ├── ImageScreeningTrainer/
│   │   │   ├── BaseScreenerTrainer.swift
│   │   │   └── ScaryCatScreenerTrainer.swift
│   │   └── TrainingCoordinator.swift
│   └── Resources/
│       └── ScaryCatScreenerData/
│           ├── Not Scary/
│           └── Scary/
├── OutputModels/
│   └── ScaryCatScreener.mlmodel
└── README.md
```

## Model Training Playground

このリポジトリには、`ScaryCatScreener.mlmodel` のトレーニングプロセスを実演するための `CatScreeningML.playground` が含まれています。Playground を使用して、独自の画像データでモデルを再トレーニングしたり、トレーニングプロセスをカスタマイズしたりする方法については、以下の詳細なドキュメントを参照してください。

- [CatScreeningML Playground ドキュメント](./CatScreeningML.playground/CAT_SCREENING_ML.md)

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
    - [詳細ドキュメント](./CatScreeningKit/Sources/ScaryCatScreener/SCARY_CAT_SCREENER.md)

今後、他の分類基準を持つスクリーナーが追加される可能性があります。

## Error Handling

`predict` メソッドは `Result<(label: String, confidence: Float), PredictionError>` を返します。失敗時には `PredictionError` で詳細なエラー内容を示します。 