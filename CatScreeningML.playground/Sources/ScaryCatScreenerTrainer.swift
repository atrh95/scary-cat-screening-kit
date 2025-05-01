import Foundation
import CoreML
import CreateML

public class ScaryCatScreenerTrainer: ScreeningTrainerProtocol {
    public var modelName: String { "ScaryCatScreeningML" }
    public var dataDirectoryName: String { "ScaryCatScreenerData" }
    public var customOutputDirPath: String { "OutputModels" }

    public var resourcesDirectoryPath: String {
        var dir = URL(fileURLWithPath: #filePath)
        dir.deleteLastPathComponent()
        dir.deleteLastPathComponent()
        return dir.appendingPathComponent("Resources").path
    }

    public init() {}

    public func train() {
        let resourcesPath = resourcesDirectoryPath

        let resourcesDir = URL(fileURLWithPath: resourcesPath)
        let trainingDataParentDir = resourcesDir.appendingPathComponent(dataDirectoryName)

        var playgroundRoot = URL(fileURLWithPath: #filePath)
        playgroundRoot.deleteLastPathComponent()
        playgroundRoot.deleteLastPathComponent()
        var baseOutputDir = playgroundRoot
        baseOutputDir.deleteLastPathComponent()

        let finalOutputDir: URL
        let customPath = customOutputDirPath
        if !customPath.isEmpty {
            let customURL = URL(fileURLWithPath: customPath)
            if customURL.isFileURL && customPath.hasPrefix("/") {
                finalOutputDir = customURL
            } else {
                finalOutputDir = baseOutputDir.appendingPathComponent(customPath)
            }
            try? FileManager.default.createDirectory(at: finalOutputDir, withIntermediateDirectories: true, attributes: nil)
        } else {
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
        
        // トレーニングパラメータ設定
        let parameters = MLImageClassifier.ModelParameters(
            augmentation: [.rotate, .crop, .flip, .blur, .exposure]
        )
        
        print("\(modelName)をトレーニング中... (パラメータ: データ拡張有効, 反復回数自動)")

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
