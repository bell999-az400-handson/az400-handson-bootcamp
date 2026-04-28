# AZ-400 3日間集中ハンズオン Bootcamp

> **最終更新**: 2026年4月28日  
> **対象試験**: AZ-400 (Microsoft Azure DevOps Solutions)  
> **シラバス**: 2026年4月24日版準拠

## 🎯 このリポジトリについて

AZ-400試験対策のための**実践的なハンズオン環境**です。模擬試験で特定された弱点領域を克服するため、3日間で以下を実装します：

- ✅ Git/GitHub高度操作（SemVer、CODEOWNERS、ブランチ戦略）
- ✅ Azure Boards統合（Work Item管理、AB#記法）
- ✅ Azure Security実践（Key Vault、Managed Identity）
- ✅ Application Insights & KQL
- ✅ CI/CD完全マスター（GitHub Actions vs Azure Pipelines）
- ✅ 実際のAzureリソースデプロイ

## 📊 学習プラン（3日間）

| Day | テーマ | 所要時間 | 主な成果物 |
|-----|--------|---------|-----------|
| **Day 1** | Git/GitHub + Azure基礎 | 4-6時間 | GitHub-Boards統合、基本インフラ |
| **Day 2** | Azure Security | 5-7時間 | Key Vault、Managed Identity、App Insights |
| **Day 3** | CI/CD完全マスター | 6-8時間 | GitHub Actions、Azure Pipelines |

詳細は [`LEARNING-PATH.md`](LEARNING-PATH.md) を参照してください。

## 🏗️ プロジェクト構造

```
az400-handson-bootcamp/
├── .github/
│   ├── copilot-instructions.md      ← Copilot最適化設定
│   ├── CODEOWNERS                   ← コードオーナー設定
│   └── workflows/                   ← GitHub Actions
├── .azure/pipelines/                ← Azure Pipelines
├── infra/bicep/                     ← インフラコード（Bicep）
│   ├── main.bicep
│   ├── modules/                     ← Key Vault、Web App等
│   └── parameters/                  ← 環境別パラメータ
├── src/webapp/                      ← サンプルWebアプリ（Node.js）
├── docs/handson/                    ← Day 1-3の詳細手順書
├── scripts/                         ← セットアップスクリプト、KQL
└── WorkItems/                       ← Azure Boards Work Item CSV
```

## 🚀 クイックスタート

### 前提条件

- Azure サブスクリプション
- Azure DevOps 組織
- Azure CLI (`az`)
- Git
- Node.js 18+
- VS Code（推奨）

### 1. リポジトリのクローン

```bash
git clone https://github.com/<your-org>/az400-handson-bootcamp.git
cd az400-handson-bootcamp
```

### 2. Azure環境のセットアップ

```bash
# Azure にログイン
az login

# サブスクリプション設定
az account set --subscription "<your-subscription-id>"

# リソースグループ作成
az group create --name rg-az400-handson --location japaneast
```

### 3. Day 1の開始

詳細は [`docs/handson/day1-git-github.md`](docs/handson/day1-git-github.md) を参照してください。

## 📚 ドキュメント

| ドキュメント | 説明 |
|------------|------|
| [LEARNING-PATH.md](LEARNING-PATH.md) | 3日間の詳細学習ロードマップ |
| [docs/handson/day1-git-github.md](docs/handson/day1-git-github.md) | Day 1: Git/GitHub実践 |
| [docs/handson/day2-azure-security.md](docs/handson/day2-azure-security.md) | Day 2: Azure Security |
| [docs/handson/day3-cicd-pipelines.md](docs/handson/day3-cicd-pipelines.md) | Day 3: CI/CD |
| [docs/architecture.md](docs/architecture.md) | アーキテクチャ図 |
| [docs/exam-tips.md](docs/exam-tips.md) | 試験対策まとめ |

## 🎓 AZ-400試験対策のポイント

### 試験配分（2026年4月24日版）
- プロセスとコミュニケーション: 10-15%
- ソース管理戦略: 10-15%
- **ビルド・リリースパイプライン: 50-55%** ⭐ 最重要
- セキュリティ・コンプライアンス: 10-15%
- インストルメンテーション: 5-10%

### 頻出トピック
1. **Azure Boards と GitHub の統合**（Work Item管理）
2. **GitHub Actions と Azure Pipelines の使い分け**
3. **Key Vault IAM vs Access Policies**
4. **Managed Identity（system/user-assigned）**
5. **KQLクエリ（bin、extend、project）**
6. **ブランチ戦略の適用判断**

## 💰 コスト見積もり

| リソース | SKU | 推定コスト（3日間） |
|---------|-----|-------------------|
| App Service | B1（Basic） | ~$15 |
| Key Vault | Standard | ~$0.15 |
| Storage Account | Standard LRS | ~$0.20 |
| Application Insights | 基本 | ~$2 |
| **合計** | | **~$17-20** |

**節約Tips**: 夜間・週末はApp Serviceを停止

## 🤝 コントリビューション

このリポジトリは学習目的です。改善提案はIssueまたはPRでお願いします。

## 📝 ライセンス

MIT License

## 🔗 参考リンク

- [AZ-400 公式シラバス](https://learn.microsoft.com/certifications/exams/az-400)
- [Azure DevOps ドキュメント](https://learn.microsoft.com/azure/devops/)
- [GitHub Actions ドキュメント](https://docs.github.com/actions)
- [Bicep ドキュメント](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)

---

**Good luck with your AZ-400 exam! 🚀**
