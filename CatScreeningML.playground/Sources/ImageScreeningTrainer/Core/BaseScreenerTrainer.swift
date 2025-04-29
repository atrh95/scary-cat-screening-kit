import CreateML
import Foundation

class BaseScreenerTrainer {
    @available(*, unavailable, message: "BaseScreenerTrainerは直接インスタンス化できません。ScaryCatScreenerTrainerのようなサブクラスを使用してください。")
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

            print("  トレーニング精度: \(model.trainingMetrics.classificationError * 100)%")
            print("  検証精度: \(model.validationMetrics.classificationError * 100)%")
            print("  モデルの説明: \(model.modelDescription)")
            print("  期待される入力: \(model.modelDescription.inputDescriptionsByName)")
            print("  期待される出力: \(model.modelDescription.outputDescriptionsByName)")

            let metadata = MLModelMetadata(
                author: "CatScreeningML Playground",
                shortDescription: "画像を分類します: \(modelName)",
                version: "1.0"
            )

            print("\(modelName)を保存中: \(outputModelPath.path)")
            try model.write(to: outputModelPath, metadata: metadata)
            print("\(modelName)は正常に保存されました。")

        } catch let error as MLError where error.isCode(.io) {
            print("モデル\(modelName)の保存エラー: I/Oエラー - \(error.localizedDescription)")
        } catch let error as MLError where error.isCode(.datumNotFound) {
            print("モデル\(modelName)のトレーニングエラー: Create MLエラー - データが見つかりません。 \(error.localizedDescription)")
            print(
                "データディレクトリ（例: \(trainingDataParentDir.path)/Cat, " +
                "\(trainingDataParentDir.path)/NotCat）が存在し、有効な画像が含まれているか確認してください。"
            )
            print("詳細なCreate MLエラー: \(error)")
        } catch let error as MLError where error.isCode(.datumUnsupportedFormat) {
            print("モデル\(modelName)のトレーニングエラー: Create MLエラー - サポートされていないデータ形式です。 \(error.localizedDescription)")
            print("\(trainingDataParentDir.path) 内の画像ファイルがサポートされている形式（例: JPG、PNG）であることを確認してください。")
            print("詳細なCreate MLエラー: \(error)")
        } catch let error as MLError {
            print("モデル\(self.modelName)のトレーニングエラー: Create MLエラー - \(error.localizedDescription)")
            print("詳細なCreate MLエラー: \(error)")
        } catch {
            print("\(modelName)のトレーニングまたは保存中に予期しないエラーが発生しました: \(error.localizedDescription)")
        }
    }
}
