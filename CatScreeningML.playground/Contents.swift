import PlaygroundSupport

// Sourcesフォルダ内のTrainModel.swiftにある関数を呼び出します。
// （TrainModel.swiftがSourcesにあれば、特別なimport文は不要です）

print("Playgroundの実行を開始します...")

// モデルのトレーニングのような非同期処理が完了するのを許可します。
PlaygroundPage.current.needsIndefiniteExecution = true

// TrainingCoordinatorのトレーニング開始メソッドを呼び出します。
TrainingCoordinator.startTraining()

print("トレーニング開始処理が完了しました。")
// 実際のトレーニングは非同期で行われます。
// 進捗や完了/エラーはコンソール出力を確認してください。

// 必要であれば、トレーニング完了後に実行を明示的に終了させることもできます。
// 例：
// DispatchQueue.main.asyncAfter(deadline: .now() + 600) { // 必要に応じて時間を調整
//     PlaygroundPage.current.finishExecution()
// }
