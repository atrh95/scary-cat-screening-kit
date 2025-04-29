# CatScreeningML

## Overview
CatScreeningMLは、Create MLを用いて猫の画像を特定の基準に基づいて、判別する機械学習モデルの作成するためのプロジェクトです。

- 訓練特化のプロジェクトです (Playground 形式)
- 生成されたモデルは手動でエクスポートします
- 推論ロジックは含まず、モデル作成に特化します

## Directory Structure
```
CatScreeningML.playground/
    ├── Data/             // 訓練用データセット (cat / not-cat)
    ├── TrainModel.swift  // Create MLを用いた訓練スクリプト
    └── README.md         // このファイル
```

## Workflow
1. `Data/` 配下にデータセットを編集
2. Playground上で `TrainModel.swift` を実行
3. 生成された `CatScreeningML.mlmodel` をエクスポート

## Purpose
このリポジトリは、機械学習モデルの作成を担当します。  
推論やユーザフレンドリーなAPIは `CatScreeningKit` Swift Packageで提供されます。

## Notes
- 再訓練したい場合は、このPlaygroundだけを更新すればOK
- Core MLやVisionのAPIを直接使うことはありません
- 推論ロジックはCatScreeningKit側で担当します

