import Foundation // FileManagerを使うために追加
import PlaygroundSupport

// モデルのトレーニングのような非同期処理が完了するのを許可します。
PlaygroundPage.current.needsIndefiniteExecution = true

// --- メタデータ定義 ---
let modelAuthor = "akitora"
let modelDescription = "ScaryCatScreener v1.0.0"
let modelVersion = "1.0.0"
// ---------------------

// トレーナークラスのインスタンスを作成
let scaryCatTrainer = ScaryCatScreenerTrainer()

// trainメソッドを呼び出し、メタデータを渡す
if let result = scaryCatTrainer.train(author: modelAuthor, shortDescription: modelDescription, version: modelVersion) {
    print("すべての処理が完了しました。")

    // 結果をファイルに記録 (TrainingResultLoggerを使用)
    TrainingResultLogger.saveResultToFile(
        result: result,
        trainer: scaryCatTrainer,
        modelAuthor: modelAuthor,
        modelDescription: modelDescription,
        modelVersion: modelVersion
    )

} else {
    print("🛑 トレーニングまたはモデルの保存中にエラーが発生しました。")
}
