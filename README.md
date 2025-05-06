# CatScreeningKit

Core MLモデルを使用した様々な猫の画像分類タスクを実行するためのSwift Packageです。

## Requirements

*   Swift 5.9+
*   iOS 15.0+

## インストール方法 (Swift Package Manager)

1. Xcode でプロジェクトを開き、「File」>「Add Packages...」を選択します。
2. 検索バーにこのリポジトリの URL (`https://github.com/terrio32/cat-screening-kit`) を貼り付けます。
3. 「Dependency Rule」でバージョンルールを選択し（例: "Up to Next Major Version" で `1.0.0` を指定）、「Add Package」をクリックします。
4. ターゲットの「Frameworks, Libraries, and Embedded Content」セクションに `CatScreeningKit` が追加されていることを確認します。

## 使い方

```swift
import SwiftUI
import CatScreeningKit

struct ContentView: View {
    // 利用したいスクリーナのインスタンスを作成
    // 例: ScaryCatScreener
    let screener = ScaryCatScreener()

    @State private var image: UIImage? = UIImage(named: "cat_image") // 判定したい画像
    @State private var resultText: String = "判定中..."

    var body: some View {
        VStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
            }
            Text(resultText)
                .padding()
            Button("猫を判定") {
                Task {
                    await performScreening()
                }
            }
        }
    }

    private func performScreening() async {
        guard let image = image else {
            resultText = "画像がありません"
            return
        }

        resultText = "判定中..."
        do {
            let report = try await screener.screen(image: image)
            // report は ScreeningReport 型
            if let detection = report.decisiveDetection {
                resultText = "結果: \(detection.identifier) (信頼度: \(String(format: "%.2f", detection.confidence * 100))%)"
            } else {
                resultText = "結果: 安全 (閾値を超えた検出なし)"
            }
        } catch let error as PredictionError {
            resultText = "エラー: \(error.localizedDescription)"
        } catch {
            resultText = "予期せぬエラー: \(error.localizedDescription)"
        }
    }
}
```

## 設計

`CatScreeningKit` は、特定の猫の特性を検出するために `ScaryCatScreener` クラスを提供します。
クライアントコードは `ScaryCatScreener` のインスタンスを直接生成して使用します。
このクラスは、画像を入力として受け取り、非同期で `ScreeningReport` オブジェクトを返します。
`ScreeningReport` には、最も可能性の高い検出結果（もしあれば）と、すべての分類クラスの信頼度スコアが含まれます。

## 利用可能なスクリーナ

### ScaryCatScreener
[詳細はこちら](./Sources/ScaryCatScreener/SCARY_CAT_SCREENER.md)

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

## モデルのトレーニングについて

このライブラリで使用されている Core ML モデルのトレーニング方法や、モデルのカスタマイズについては、以下の別リポジトリを参照してください。

➡️ **[terrio32/train-cat-screening-ml](https://github.com/terrio32/train-cat-screening-ml)**