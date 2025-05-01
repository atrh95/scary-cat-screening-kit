import Foundation

/// 画像分類モデルトレーナー
public protocol ScreeningTrainerProtocol {
    /// モデル名
    var modelName: String { get }

    /// データディレクトリ名 (リソース内相対パス)
    var dataDirectoryName: String { get }

    /// 出力先ディレクトリパス
    var customOutputDirPath: String { get }

    /// リソースディレクトリ絶対パス
    var resourcesDirectoryPath: String { get }

    /// トレーニング実行 (読み込み、学習、評価、保存)
    func train()
}