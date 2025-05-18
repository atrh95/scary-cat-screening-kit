# ScaryCatScreeningKit

## プロジェクト概要

ScaryCatScreeningKitは、潜在的に「不安全な」猫の画像を検出しフィルタリングするための画像スクリーニング機能を提供する Swift パッケージです。機械学習モデルを使用して画像を分類し、設定可能な確率の閾値に基づいて安全性を判断します。現在はOne-vs-Rest (OvR) 分類アプローチを利用できます。

**One-vs-Rest (OvR) 分類**: 複数のバイナリ分類器を使用し、それぞれが特定のカテゴリに特化しています。

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/aktrh/scary-cat-screening-kit)

## 設計方針

*   **ScaryCatScreeningKit**: 複数のOne-vs-Restモデルを使用した画像スクリーニング機能を提供します。CoreMLモデルを活用し、設定可能な閾値に基づいて画像を分類します。 ([詳細](./Sources/ScaryCatScreeningKit/OvRScaryCatScreener.md))

## ディレクトリ構成

```tree
.
├── SampleApp/
├── Sources/
│   └── ScaryCatScreeningKit/
│       ├── OvRScaryCatScreener.md
│       ├── OvRScaryCatScreener.swift
│       ├── OvRScreeningReport.swift
│       ├── ScaryCatScreenerError.swift
│       ├── SCSReporterProtocol.swift
│       └── Resources/
├── Package.swift
├── project.yml
└── README.md
```

## 使用技術

*   **言語** Swift 6.0
*   **プラットフォーム** iOS 15.0以降
*   **依存性管理** Package.swift
*   **プロジェクト生成** XcodeGen
*   **機械学習** CoreMLモデル

## 機能詳細

### 画像スクリーニングワークフロー

スクリーニングプロセスは以下のステップで進行します。

1.  設定可能な確率の閾値と共に、`screen()` メソッド経由で UIImage を送信します。
2.  Vision フレームワークと CoreML モデルを使用して各 UIImage を処理します。
3.  閾値を超える信頼度を持つ分類結果は、 UIImage を不安全としてマークします。
4.  安全な UIImage のみがアプリケーションに返却されます。
5.  オプションのログ機能により、詳細なスクリーニングレポートの取得が可能です。

### スクリーナー実装

ScaryCatScreeningKitは、複数のバイナリ分類器（One-vs-Rest）を使用して画像をスクリーニングする機能を提供します。各分類器は特定のカテゴリに特化しており、タスクグループによる並列処理を活用して効率的な評価を行います。モデルは ".mlmodelc" 拡張子を持つものが自動的にロードされます。

### エラーハンドリング

フレームワークは `ScaryCatScreenerError` enumを通じて包括的なエラーハンドリングシステムを実装しています。このエラー型は `ScaryCatScreeningKit` モジュールで定義されており、 `NSError` に変換して throw されます。

| エラータイプ                       | 説明                                                         |
| -------------------------------- | ------------------------------------------------------------ |
| `resourceBundleNotFound`         | MLモデルを含むリソースバンドルが見つからない場合に発生します。     |
| `modelLoadingFailed(originalError:)` | MLモデルの読み込み中にエラーが発生した場合に発生します。           |
| `modelNotFound`                  | 必要なMLモデルファイルが見つからない場合に発生します。             |
| `predictionFailed(originalError:)`   | 画像分類中にエラーが発生した場合に発生します。                   |

