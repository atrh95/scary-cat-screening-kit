import Foundation

class ScaryCatScreenerTrainer: BaseScreenerTrainer {
    override var modelName: String { "ScaryCatScreener" }
    override var dataDirectoryName: String { "ScaryCatScreenerData" }
    override var customOutputDirPath: String { "CatScreeningKit/Sources/ScaryCatScreener/Resource" }

    // このファイルの位置を基準にPlaygroundのResourcesディレクトリパスを計算
    override var resourcesDirectoryPath: String? {
        var dir = URL(fileURLWithPath: #filePath)
        dir.deleteLastPathComponent() // -> ImageScreeningTrainer
        dir.deleteLastPathComponent() // -> Sources
        dir.deleteLastPathComponent() // -> CatScreeningML.playground
        return dir.appendingPathComponent("Resources").path
    }

    override init() {}
}
