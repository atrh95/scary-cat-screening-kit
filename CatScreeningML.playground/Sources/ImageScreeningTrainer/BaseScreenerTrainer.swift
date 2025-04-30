import CreateML
import CoreML
import Foundation

class BaseScreenerTrainer {
    init() {}

    // サブクラスでオーバーライドされるべきプロパティ
    var modelName: String { fatalError("サブクラスでオーバーライドする必要があります") }
    var dataDirectoryName: String { fatalError("サブクラスでオーバーライドする必要があります") }

    final func train(resourcesDir: URL, outputDir: URL) {
        let trainingDataParentDir = resourcesDir.appendingPathComponent(dataDirectoryName)
        let outputModelPath = outputDir.appendingPathComponent("\(modelName).mlmodel")

        print("\n\(modelName)のトレーニングを開始します...")
        print("  データソース: \(trainingDataParentDir.path)")

        executeTrainingCore(trainingDataParentDir: trainingDataParentDir, outputModelPath: outputModelPath)
    }

    private func executeTrainingCore(trainingDataParentDir: URL, outputModelPath: URL) {
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

            // 既存のモデルファイルを削除 (存在しない場合はエラーを無視)
            do {
                try FileManager.default.removeItem(at: outputModelPath)
                print("既存のモデルファイルを削除しました: \(outputModelPath.path)")
            } catch CocoaError.fileNoSuchFile {
                // ファイルが存在しない場合は何もしない
                print("既存のモデルファイルは見つかりませんでした。削除はスキップします。")
            } catch {
                // その他の削除エラー（権限など）は警告として出力
                print("警告: 既存のモデルファイルの削除中にエラーが発生しました: \(error.localizedDescription)")
            }

            print("\(modelName)を保存中: \(outputModelPath.path)")
            try model.write(to: outputModelPath, metadata: metadata)
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
