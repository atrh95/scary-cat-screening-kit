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
    let screener: any CatScreenerProtocol = ScaryCatScreener()

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
            let result = try await screener.screen(image: image)
            // result は (label: String, confidence: Float) のタプル
            resultText = "結果: \(result.label) (信頼度: \(String(format: "%.2f", result.confidence * 100))%)"
        } catch let error as PredictionError {
            resultText = "エラー: \(error.localizedDescription)"
        } catch {
            resultText = "予期せぬエラー: \(error.localizedDescription)"
        }
    }
}
```

## 設計

`CatScreeningKit` の中心となるのは `CatScreenerProtocol` です。これは `minConfidence` プロパティと、画像を受け取り、分類結果またはエラーを `async` で返す `screen` メソッドを定義します。クライアントコードは具体的な実装クラス（例: `ScaryCatScreener`）のインスタンスを直接生成するか、このプロトコルに依存することにより、テスト時にモックオブジェクトを容易に注入でき、新しいスクリーナを追加する際も既存コードへの影響を抑えられます。

## 利用可能なスクリーナ

### ScaryCatScreener
[詳細はこちら](Sources/Screeners/ScaryCatScreener/SCARY_CAT_SCREENER.md)
(内部で使用している Core ML モデル: `ScaryCatScreeningML.mlmodel`)

## ディレクトリ構成

```
.
├── .cursor/
├── .github/
│   └── workflows/
├── Sources/
│   ├── CatScreeningKit/
│   ├── CSKShared/
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