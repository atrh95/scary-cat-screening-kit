import PlaygroundSupport

// Sourcesフォルダ内のTrainModel.swiftにある関数を呼び出します。

print("Playgroundの実行を開始します...")

// モデルのトレーニングのような非同期処理が完了するのを許可します。
PlaygroundPage.current.needsIndefiniteExecution = true

// TrainingCoordinatorのトレーニング開始メソッドを呼び出します。
TrainingCoordinator.startTraining()

print("トレーニング開始処理が完了しました。")
// 実際のトレーニングは非同期で行われます。
// 進捗や完了/エラーはコンソール出力を確認してください。
