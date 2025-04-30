import Foundation
import PlaygroundSupport

// --- トレーニング全体の調整役 ---

public enum TrainingCoordinator {
    // #filePath を使って Resources ディレクトリへのパスを構築
    private static let resourcesDirectory: URL = {
        var dir = URL(fileURLWithPath: #filePath)
        dir.deleteLastPathComponent() // TrainingCoordinator.swift -> Sources
        dir.deleteLastPathComponent() // Sources -> CatScreeningML.playground (ここで止める)
        return dir.appendingPathComponent("Resources")
    }()

    // outputDirectory を .playground と同じ階層（親ディレクトリ）に変更
    private static let outputDirectory: URL = {
        var dir = URL(fileURLWithPath: #filePath)
        dir.deleteLastPathComponent() // TrainingCoordinator.swift -> Sources
        dir.deleteLastPathComponent() // Sources -> CatScreeningML.playground
        dir.deleteLastPathComponent() // CatScreeningML.playground -> 親ディレクトリ (cat-screening-ml)
        return dir.appendingPathComponent("OutputModels")
    }()

    // --- トレーニングプロセス開始のエントリーポイント ---
    public static func startTraining() {
        print("\n--- CatScreeningML トレーニング開始 ---")
        print("Resourcesディレクトリを使用: \(resourcesDirectory.path)")
        print("モデルの出力先: \(outputDirectory.path)")

        // 出力ディレクトリが存在することを確認します。
        do {
            try FileManager.default.createDirectory(
                at: outputDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            print("出力ディレクトリを作成/確認しました: \(outputDirectory.path)")
        } catch {
            print("致命的エラー: 出力ディレクトリの作成に失敗しました: \(error.localizedDescription)")
            print("--- トレーニング中止 ---")
            return
        }

        // --- 各モデルのトレーナークラスのインスタンスを作成 ---
        let scaryCatTrainer = ScaryCatScreenerTrainer()

        // --- 各インスタンスのtrainメソッドを呼び出し ---
        scaryCatTrainer.train(resourcesDir: resourcesDirectory, outputDir: outputDirectory)

        print("\n--- 全てのトレーニングプロセスを開始しました --- ")
        print("モデルは（成功した場合）次の場所に保存されます: \(outputDirectory.path)")
        print("コンソールのログで各モデルのトレーニング結果を確認してください。")
        print("-----------------------------------------")
    }
}
