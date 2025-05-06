# ScaryCatScreeningML.mlmodel 活用ガイド

## 概要

このドキュメントは、`ScaryCatScreeningML.playground` でトレーニングされた `ScaryCatScreeningML.mlmodel` を実際のアプリケーション (iOS など) で使用し、猫の画像が「安全 (Safe)」か「安全でない (Not Safe)」かを判定するための推奨ロジックについて説明します。

## モクラスラベル

*   **クラスラベル:** モデルは以下のクラスラベルを予測します。
    *   `Safe`
    *   `BlackAndWhite`
    *   `Faded`
    *   `HumanHandsDetected`
    *   `MouthOpen`
    *   `Scary`
    *   `Sphynx`
    *   `TooHighSaturation`

## 推奨される判定ロジック (推論時)

従来の多クラス分類の最も確率の高いクラスを採用するのではなく、以下のロジックを使用します。

1.  **確率スコアの取得:** アプリケーション内で、`ScaryCatScreeningML.mlmodel` を使用して入力画像のクラス確率を予測します。Vision フレームワークを使うと、各クラスラベルとその信頼度 (確率) のリストが得られます。
2.  **「怖い特徴」の特定:** 以下のクラスラベルを「怖い特徴 (Scary Features)」として定義します。
    *   `BlackAndWhite`
    *   `Faded`
    *   `HumanHandsDetected`
    *   `MouthOpen`
    *   `Scary`
    *   `Sphynx`
    *   `TooHighSaturation`
3.  **閾値判定:**
    *   事前に**閾値 (Threshold)** を決定します (例: `0.3` や `0.2` など、これは実験的に調整する必要があります)。
    *   すべての「怖い特徴」クラスについて、モデルが予測した確率スコアを確認します。
    *   **いずれか一つでも**「怖い特徴」クラスの確率が設定した**閾値を超えている場合**、その画像は**「Not Safe」**と判定します。(`Safe` クラスの確率が高くても無視します)。
    *   **すべての**「怖い特徴」クラスの確率が**閾値以下の場合**にのみ、その画像を**「Safe」**と判定します。

**考え方:** このロジックは、「Safe であること」を積極的に証明するのではなく、「Safe でない証拠 (＝何らかの怖い特徴の確率がある程度高いこと) がないこと」をもって Safe と判断します。これは、`Safe` クラス自体の予測信頼度よりも、特定の「怖い特徴」の検出の方が信頼できる可能性があるという仮定に基づいています。

## Swift 実装例 (Vision フレームワーク使用)

以下は、上記のロジックを iOS アプリなどで実装する際の基本的な例です。

```swift
import Vision
import CoreImage // CIImageを使う場合

// --- 定数定義 ---
// アプリ内にバンドルしたモデル名を指定
let MODEL_NAME = "ScaryCatScreeningML"
// 怖い特徴と判定する閾値 (0.0 ~ 1.0)。実験的に調整してください。
let SCARY_FEATURE_THRESHOLD: Double = 0.3
// 怖い特徴クラスのリスト
let SCARY_FEATURE_LABELS: Set<String> = [
    "BlackAndWhite", "Faded", "HumanHandsDetected", "MouthOpen",
    "Scary", "Sphynx", "TooHighSaturation"
]
// ---

// Vision リクエストの準備 (一度だけ行う)
var visionModel: VNCoreMLModel? = {
    guard let modelURL = Bundle.main.url(forResource: MODEL_NAME, withExtension: "mlmodelc"), // コンパイル済みモデルを使用
          let model = try? MLModel(contentsOf: modelURL) else {
        print("❌ Error: Failed to load compiled ML model.")
        return nil
    }
    return try? VNCoreMLModel(for: model)
}()

// 画像判定関数 (非同期処理を考慮)
func predictImageSafety(image: CGImage, completion: @escaping (String?) -> Void) {
    guard let visionModel = visionModel else {
        print("❌ Error: Vision model is not loaded.")
        completion(nil)
        return
    }

    let request = VNCoreMLRequest(model: visionModel) { request, error in
        if let error = error {
            print("❌ Error during prediction: \(error.localizedDescription)")
            completion(nil) // エラー時は nil を返す
            return
        }

        guard let results = request.results as? [VNClassificationObservation] else {
            print("❌ Error: Could not cast results to VNClassificationObservation")
            completion(nil) // エラー時は nil を返す
            return
        }

        var isNotSafe = false
        print("--- Prediction Probabilities ---")
        for classification in results {
            let identifier = classification.identifier
            let confidence = Double(classification.confidence) // Doubleに変換
            print("  \(identifier): \(String(format: "%.2f", confidence * 100))%")

            // 怖い特徴クラス かつ 閾値を超えているかチェック
            if SCARY_FEATURE_LABELS.contains(identifier) && confidence > SCARY_FEATURE_THRESHOLD {
                isNotSafe = true
                print("    🚨 Found scary feature ('\(identifier)') above threshold (\(SCARY_FEATURE_THRESHOLD * 100)%): \(String(format: "%.2f", confidence * 100))%")
                // break // 一つでも見つかればNot Safeなのでループを抜けても良い
            }
        }
        print("-----------------------------")

        let finalResult = isNotSafe ? "Not Safe" : "Safe"
        completion(finalResult) // 結果をコールバックで返す
    }

    // リクエストハンドラを作成して実行
    // 注意: orientation は画像の向きに応じて適切に設定してください
    let handler = VNImageRequestHandler(cgImage: image, options: [:]) // orientation: .up など
    DispatchQueue.global(qos: .userInitiated).async {
        do {
            try handler.perform([request])
        } catch {
            print("❌ Error: Failed to perform Vision request: \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion(nil) // エラー時はメインスレッドで nil を返す
            }
        }
    }
}

// --- 呼び出し例 ---
// let inputImage: CGImage = ... // UIImageなどからCGImageを取得
// predictImageSafety(image: inputImage) { result in
//     DispatchQueue.main.async { // UI更新はメインスレッドで
//         if let safetyStatus = result {
//             print("判定結果: \(safetyStatus)")
//             // ここで判定結果に応じてUIを更新など
//         } else {
//             print("判定に失敗しました。")
//         }
//     }
// }

```

## 実装上の考慮事項

*   **非同期処理:** Vision フレームワークによる予測は非同期で行う必要があります。上記コード例のように、完了ハンドラ (Completion Handler) や Swift Concurrency (`async`/`await`) を使用して、予測結果を待ってから処理を進めるようにしてください。UI の更新は必ずメインスレッドで行います。
*   **閾値の調整:** `SCARY_FEATURE_THRESHOLD` の値は非常に重要です。どの程度の確率で「怖い特徴」と見なすかは、実際のデータやユースケースに合わせて実験的に調整する必要があります。Playground の `predictSafety` メソッド（もし残っていれば）や、実際のアプリでのテストを通じて、誤判定（False Positive/False Negative）のバランスを見ながら最適な値を探してください。
*   **モデルの更新:** 新しいモデルをトレーニングした場合、アプリケーションにバンドルする `.mlmodelc` ファイルを更新する必要があります。
*   **エラーハンドリング:** モデルのロード失敗や予測中のエラーに対するハンドリングを適切に実装してください。 