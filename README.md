# CatScreeningKit

Core MLモデルを使用した様々な猫の画像分類タスクを実行するためのSwift Packageです。

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

### Playgroundの実行
Xcodeで `CatScreeningKit` プロジェクトを開き、ナビゲーターから `CatScreeningML.playground` を選択して実行（▶︎）します。`Contents.swift` が `Sources` 内の `ScaryCatScreenerTrainer` を使用してトレーニングを開始します。進捗、結果、エラー、モデル保存先はコンソールに出力されます。

### トレーニングの設定
*   **パスと名前:** `modelName`, `dataDirectoryName`, `customOutputDirPath`, `resourcesDirectoryPath` で、モデル名、データディレクトリ名、出力先、リソースディレクトリのパスを指定します。
*   **トレーニングパラメータ:** `executeTrainingCore` メソッド内の `MLImageClassifier.ModelParameters` で、データ拡張 (`augmentation`) や最大反復回数 (`maxIterations`) など、モデルの学習プロセスに影響を与えるパラメータを設定します。
*   **モデルメタデータ:** `Contents.swift` 内で定義されたメタデータ（作成者 `author`, 概要 `shortDescription`, バージョン `version`）が、`train` メソッドを通じてモデルファイルに埋め込まれます。

### トレーニング用のデータ
画像データは `CatScreeningML.playground/Resources/ScaryCatScreenerData/` 内に配置します。クラス名（例: `Scary`, `Not Scary`）と同じ名前のサブディレクトリを作成し、画像を入れます。

### 出力モデル
トレーニングが成功すると、`customOutputDirPath` で指定されたディレクトリ（デフォルト: `OutputModels/ScaryCatScreeningML/`）内に `result_N`（Nは連番）というサブディレクトリが作成され、その中に `.mlmodel` ファイルが生成されます。このモデルファイルには、トレーニング時に指定されたメタデータ（作成者、概要、バージョン）が付与されています。生成されたモデルを `CatScreeningKit` で使用するには、`CatScreeningKit/Sources/ScaryCatScreener/Resource/` にコピーしてください。

### 精度改善
モデル精度改善のヒントは [AccuracyImprovementTips.md](CatScreeningML.playground/Sources/AccuracyImprovementTips.md) を参照してください。

## 設計

`CatScreeningKit` の中心となるのは `CatScreenerProtocol` です。これは画像を受け取り、分類結果またはエラーを非同期で返す `screen` メソッドを定義します。クライアントコードは具体的な実装クラス（例: `ScaryCatScreener`）ではなく、このプロトコルに依存することにより、テスト時にモックオブジェクトを容易に注入でき、新しいスクリーナを追加する際も既存コードへの影響を抑えられます。

## 利用可能なスクリーナー

### ScaryCatScreener

猫の画像が「怖い」か「怖くない」かを分類します。
詳細は [SCARY_CAT_SCREENER.md](CatScreeningKit/Sources/ScaryCatScreener/SCARY_CAT_SCREENER.md) を参照してください。