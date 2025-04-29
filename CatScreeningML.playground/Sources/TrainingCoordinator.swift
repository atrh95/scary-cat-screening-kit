import Foundation

// --- トレーニング全体の調整役 ---

public struct TrainingCoordinator {

    private static let playgroundRootUrl: URL = {
        guard let resourceUrl = Bundle.main.resourceURL else {
            print("エラー: バンドルリソースURLが見つかりません。一時ディレクトリをデフォルトにします。")
            return FileManager.default.temporaryDirectory.appendingPathComponent("CatScreeningML_Fallback")
        }
        let potentialRoot = resourceUrl.deletingLastPathComponent()
        print("特定されたPlaygroundルートURL: \(potentialRoot.path)")
        return potentialRoot
    }()

    private static let resourcesDirectory: URL = playgroundRootUrl.appendingPathComponent("Resources")
    private static let outputDirectory: URL = playgroundRootUrl.appendingPathComponent("OutputModels")

    // --- トレーニングプロセス開始のエントリーポイント ---
    public static func startTraining() {
        print("\n--- CatScreeningML トレーニング開始 ---")
        print("Resourcesディレクトリを使用: \(resourcesDirectory.path)")
        print("モデルの出力先: \(outputDirectory.path)")

        // 出力ディレクトリが存在することを確認します。
        do {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true, attributes: nil)
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