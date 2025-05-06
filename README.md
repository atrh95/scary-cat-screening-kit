# CatScreeningKit

Core MLモデルを使用した様々な猫の画像分類タスクを実行するためのSwift Packageです。

## ディレクトリ構成

```
.
├── .cursor/
├── .github/
│   └── workflows/
├── Sources/
│   ├── CatScreeningKit/
│   └── ScaryCatScreener/
│       └── Resources/
├── Tests/
│   └── ScaryCatScreenerTests/
│       ├── NotScary/
│       └── Scary/
├── .gitignore
├── .swiftformat
├── .swiftlint.yml
├── LICENSE
├── Mintfile
├── Package.swift
└── README.md
```

## 利用可能なスクリーナ

### ScaryCatScreener
[詳細はこちら](./Sources/ScaryCatScreener/SCARY_CAT_SCREENER.md)

## インストール方法 (Swift Package Manager)

1. Xcode でプロジェクトを開き、「File」>「Add Packages...」を選択します。
2. 検索バーにこのリポジトリの URL (`https://github.com/terrio32/cat-screening-kit`) を貼り付けます。
3. 「Dependency Rule」でバージョンルールを選択し（例: "Up to Next Major Version" で `1.0.0` を指定）、「Add Package」をクリックします。
4. ターゲットの「Frameworks, Libraries, and Embedded Content」セクションに `CatScreeningKit` が追加されていることを確認します。

## Requirements

*   Swift 5.9+
*   iOS 15.0+

## モデルのトレーニング

このライブラリで使用されている Core ML モデルのトレーニング方法や、モデルのカスタマイズについては、以下の別リポジトリを参照してください。

➡️ **[terrio32/train-cat-screening-ml](https://github.com/terrio32/train-cat-screening-ml)**