import PlaygroundSupport

// Sourcesフォルダ内のTrainModel.swiftにある関数を呼び出します。

print("Playgroundの実行を開始します...")

// モデルのトレーニングのような非同期処理が完了するのを許可します。
PlaygroundPage.current.needsIndefiniteExecution = true

// --- トレーニング開始処理 (元 TrainingCoordinator.startTraining) ---
print("--- CatScreeningML トレーニング開始 ---")

// トレーナークラスのインスタンスを作成、trainメソッドを呼び出し
let scaryCatTrainer = ScaryCatScreenerTrainer()
scaryCatTrainer.train()

print("\n--- トレーニング処理を開始しました --- ")
print("非同期で実行するため、完了まで時間がかかる場合があります。")
print("結果はこちらのコンソールに出力されます。")
print("-----------------------------------------")