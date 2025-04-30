import CoreML
import CreateML
import Foundation

class BaseScreenerTrainer {
    init() {}

    // サブクラスでオーバーライド必須
    var modelName: String { fatalError("サブクラスでオーバーライドする必要があります") }
    var dataDirectoryName: String { fatalError("サブクラスでオーバーライドする必要があります") }

    // カスタム出力ディレクトリパス (デフォルト: "OutputModels")
    var customOutputDirPath: String { "OutputModels" }

    // リソースディレクトリのパス (サブクラスで設定必須)
    var resourcesDirectoryPath: String? { nil }

    final func train() {
        // リソースパスの検証
        guard let resourcesPath = resourcesDirectoryPath, !resourcesPath.isEmpty else {
            print("エラー: \(modelName) の resourcesDirectoryPath が設定されていません。サブクラスでオーバーライドしてください。")
            return
        }
        let resourcesDir = URL(fileURLWithPath: resourcesPath)

        let trainingDataParentDir = resourcesDir.appendingPathComponent(dataDirectoryName)

        // 出力先決定のためPlaygroundのルートと親ディレクトリを計算
        var playgroundRoot = URL(fileURLWithPath: #filePath)
        playgroundRoot.deleteLastPathComponent() // -> ImageScreeningTrainer
        playgroundRoot.deleteLastPathComponent() // -> Sources
        playgroundRoot.deleteLastPathComponent() // -> CatScreeningML.playground
        var baseOutputDir = playgroundRoot
        baseOutputDir.deleteLastPathComponent() // -> 親ディレクトリ

        // 最終的な出力ディレクトリを決定
        let finalOutputDir: URL
        let customPath = customOutputDirPath
        if !customPath.isEmpty {
            let customURL = URL(fileURLWithPath: customPath)
            if customURL.isFileURL && customPath.hasPrefix("/") { // 絶対パス
                finalOutputDir = customURL
            } else { // 相対パス
                finalOutputDir = baseOutputDir.appendingPathComponent(customPath)
            }
            try? FileManager.default.createDirectory(at: finalOutputDir, withIntermediateDirectories: true, attributes: nil)
        } else {
            // customOutputDirPathが空の場合 (通常発生しない)
            print("警告: customOutputDirPathが空です。デフォルトのOutputModelsを使用します。")
            finalOutputDir = baseOutputDir.appendingPathComponent("OutputModels")
            try? FileManager.default.createDirectory(at: finalOutputDir, withIntermediateDirectories: true, attributes: nil)
        }

        print("\n\(modelName)のトレーニングを開始します...")
        print("  データソース: \(trainingDataParentDir.path)")
        print("  出力先ディレクトリ: \(finalOutputDir.path)")

        executeTrainingCore(trainingDataParentDir: trainingDataParentDir, outputDir: finalOutputDir)
    }

    private func executeTrainingCore(trainingDataParentDir: URL, outputDir: URL) {
        print("\(modelName)のデータを親ディレクトリから読み込みます: \(trainingDataParentDir.path)")

        guard FileManager.default.fileExists(atPath: trainingDataParentDir.path) else {
            print("エラー: \(modelName)のトレーニングデータ親ディレクトリが見つかりません: \(trainingDataParentDir.path)")
            return
        }
        print("\(modelName)の親ディレクトリが見つかりました。")

        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: trainingDataParentDir.path)
            print("  \(trainingDataParentDir.lastPathComponent)の内容: \(contents)")
        } catch {
            print("警告: トレーニングデータ親ディレクトリの内容をリストできませんでした: \(error)")
        }

        let trainingDataSource = MLImageClassifier.DataSource.labeledDirectories(at: trainingDataParentDir)
        let parameters = MLImageClassifier.ModelParameters()
        print("\(modelName)をトレーニング中... (時間がかかる場合があります)")

        do {
            let model = try MLImageClassifier(trainingData: trainingDataSource, parameters: parameters)
            print("\(modelName)のトレーニングに成功しました！")

            let trainingError = model.trainingMetrics.classificationError
            let trainingAccuracy = (1.0 - trainingError) * 100
            let trainingErrorStr = String(format: "%.2f", trainingError * 100)
            let trainingAccStr = String(format: "%.2f", trainingAccuracy)
            print("  トレーニングエラー率: \(trainingErrorStr)% (正解率: \(trainingAccStr)%)")

            let validationError = model.validationMetrics.classificationError
            let validationAccuracy = (1.0 - validationError) * 100
            let validationErrorStr = String(format: "%.2f", validationError * 100)
            let validationAccStr = String(format: "%.2f", validationAccuracy)
            print("  検証エラー率: \(validationErrorStr)% (正解率: \(validationAccStr)%)")

            let metadata = MLModelMetadata(
                author: "CatScreeningML Playground",
                shortDescription: "画像を分類します: \(modelName)",
                version: "1.0"
            )

            let fileManager = FileManager.default
            var outputModelURL = outputDir.appendingPathComponent("\(modelName).mlmodel")
            var counter = 1
            let baseName = modelName
            let fileExtension = "mlmodel"

            // 同名ファイルが存在する場合は連番を付与
            while fileManager.fileExists(atPath: outputModelURL.path) {
                let newName = "\(baseName)_\(counter).\(fileExtension)"
                outputModelURL = outputDir.appendingPathComponent(newName)
                counter += 1
            }

            print("\(modelName)を保存中: \(outputModelURL.path)")
            try model.write(to: outputModelURL, metadata: metadata)
            print("\(modelName)は正常に保存されました。")

        } catch let error as CreateML.MLCreateError {
            switch error {
                case .io:
                    print("モデル\(modelName)の保存エラー: I/Oエラー - \(error.localizedDescription)")
                default:
                    print("モデル\(self.modelName)のトレーニングエラー: 未知の Create MLエラー - \(error.localizedDescription)")
                    print("詳細なCreate MLエラー: \(error)")
            }
        } catch {
            print("\(modelName)のトレーニングまたは保存中に予期しないエラーが発生しました: \(error.localizedDescription)")
        }
    }
}
