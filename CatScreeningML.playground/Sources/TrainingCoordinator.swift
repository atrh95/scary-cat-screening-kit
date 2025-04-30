import Foundation
import PlaygroundSupport

// トレーニングプロセス全体を調整します。
public enum TrainingCoordinator {

    // トレーニングプロセスを開始します。
    public static func startTraining() {
        print("\n--- CatScreeningML トレーニング開始 ---")

        // トレーナークラスのインスタンスを作成
        let scaryCatTrainer = ScaryCatScreenerTrainer()

        // trainメソッドを呼び出し
        scaryCatTrainer.train()

        print("\n--- 全てのトレーニングプロセスを開始しました --- ")
        print("コンソールのログで各モデルのトレーニング結果と保存先を確認してください。")
        print("-----------------------------------------")
    }
}
