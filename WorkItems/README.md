# Azure DevOps Work Items

このフォルダには、AZ-400 Handson Bootcampプロジェクトのワークアイテムが含まれています。

## ファイル

- `az400-handson-workitems.csv`: 全Work Itemの一覧（CSV形式）

## Work Item階層

```
Epic: AZ-400 Handson Bootcamp (3日間)
├── Feature: Day 1: Git/GitHub/Azure DevOps基礎
│   ├── User Story: 環境セットアップ
│   │   ├── Task: Azure CLI インストール確認
│   │   ├── Task: VS Code + 拡張機能インストール
│   │   └── Task: Azureサブスクリプション確認
│   ├── User Story: Gitリポジトリ初期化とAzure Boards連携
│   │   ├── Task: GitHubリポジトリ作成
│   │   ├── Task: ローカルリポジトリ初期化
│   │   ├── Task: Azure DevOps プロジェクト作成
│   │   ├── Task: GitHub-Azure Boards連携設定
│   │   └── Task: AB#記法の動作確認
│   ├── User Story: CODEOWNERSとSemVer実践
│   │   ├── Task: CODEOWNERSファイル作成
│   │   ├── Task: SemVerルール理解
│   │   └── Task: package.jsonバージョン管理
│   └── User Story: Bicepで基本インフラデプロイ
│       ├── Task: main.bicep作成
│       ├── Task: dev.parameters.json作成
│       ├── Task: Bicepデプロイ実行
│       └── Task: デプロイ結果確認
├── Feature: Day 2: Azure Security (Key Vault/Managed Identity)
│   ├── User Story: Key Vault IAM vs Access Policies理解
│   │   ├── Task: Key Vault作成（Bicep）
│   │   ├── Task: Access Policies設定
│   │   ├── Task: IAM設定
│   │   └── Task: 動作確認
│   ├── User Story: Managed Identity実装
│   │   ├── Task: Web App with Managed Identity作成
│   │   ├── Task: Node.js SDK実装
│   │   └── Task: system vs user-assigned理解
│   ├── User Story: Application Insights統合
│   │   ├── Task: Application Insights作成（Bicep）
│   │   ├── Task: SDK統合
│   │   ├── Task: カスタムメトリクス送信
│   │   └── Task: Azure Portalで確認
│   └── User Story: KQL実践
│       ├── Task: 基本クエリ実行
│       ├── Task: bin()で時間集計
│       ├── Task: extend vs project理解
│       └── Task: percentile()実践
└── Feature: Day 3: CI/CD完全マスター
    ├── User Story: GitHub Actions CI/CD実装
    │   ├── Task: Service Principal作成
    │   ├── Task: GitHub Secrets設定
    │   ├── Task: CI Pipeline YAML作成
    │   ├── Task: CD Pipeline YAML作成
    │   ├── Task: Dependabot設定
    │   └── Task: CodeQL設定
    ├── User Story: Azure Pipelines CI/CD実装
    │   ├── Task: Service Connection設定
    │   ├── Task: azure-pipelines.yml作成
    │   ├── Task: Branch Policy設定
    │   └── Task: パイプライン実行確認
    ├── User Story: GitHub Actions vs Azure Pipelines比較
    │   ├── Task: 比較表作成
    │   ├── Task: 使い分けガイドライン理解
    │   └── Task: 並列ジョブの概念理解
    └── User Story: 完全なDevOpsワークフロー実行
        ├── Task: 新機能Work Item作成
        ├── Task: feature ブランチ作成
        ├── Task: AB#記法でコミット
        ├── Task: PR作成
        ├── Task: CI/CD実行確認
        ├── Task: Application Insights監視
        └── Task: Work Item自動クローズ確認
```

## インポート方法

### Azure DevOpsへのインポート

Azure DevOps Web UIでは直接CSVインポートができないため、以下の方法を使用します：

#### オプション 1: Azure DevOps REST API

```bash
# Azure DevOps拡張機能が必要
az extension add --name azure-devops

# 組織とプロジェクトを設定
az devops configure --defaults organization=https://dev.azure.com/your-org project=your-project

# Work Item作成（スクリプトで自動化）
# 詳細は scripts/setup/02-configure-devops.sh を参照
```

#### オプション 2: Excelを使用

1. CSVファイルをExcelで開く
2. Azure DevOps > Boards > Work items > ... > Import work items
3. Excelファイルをアップロード

#### オプション 3: 手動作成

CSVファイルを参照しながら、Azure DevOps Web UIで手動作成。

## Work Item統計

- **Epic**: 1個
- **Feature**: 3個
- **User Story**: 13個
- **Task**: 49個
- **合計**: 66個

## タグ一覧

- `az400` - AZ-400試験関連
- `exam-prep` - 試験対策
- `day1`, `day2`, `day3` - 日別タグ
- `git`, `github`, `bicep`, `keyvault`, `cicd` など - 技術タグ
