# AZ-400 3日間集中学習ロードマップ

> **対象**: AZ-400試験受験者  
> **期間**: 3日間（合計15-21時間）  
> **形式**: 実践型ハンズオン

## 🎯 学習目標

このロードマップは、模擬試験で特定された以下の弱点領域を克服します：

1. **Azure DevOps管理** - Key Vault IAM、Managed Identity、保持ポリシー
2. **Git/GitHub運用** - SemVer、CODEOWNERS、ブランチ戦略
3. **Azure Boards** - Cycle time vs Lead time、依存関係管理
4. **App Insights/KQL** - KQLクエリ、メトリクス可視化
5. **Azure Pipelines** - 並列ジョブ、エージェントプール
6. **セキュリティ** - OAuth、条件付きアクセス

---

## 📅 Day 1: Git/GitHub高度操作 + Azure基礎

**所要時間**: 4-6時間  
**目標**: GitHub-Azure DevOps統合、Git高度操作、基本インフラデプロイ

### 午前セッション（2-3時間）

#### 1. 環境セットアップ（30分）
- [ ] GitHubリポジトリ作成
- [ ] Azure DevOpsプロジェクト作成
- [ ] ローカル開発環境確認（Azure CLI、Git、Node.js）

#### 2. Azure Boards統合（45分）
- [ ] Azure Boards で Epic/Feature/User Story作成
- [ ] GitHub統合設定（AB#記法有効化）
- [ ] Work Item階層理解
- [ ] Cycle Time vs Lead Time理解

**実践タスク**:
```bash
# Epic作成
Epic #1: AZ-400ハンズオン環境構築

# Feature作成
Feature #2: Git/GitHub基礎実装

# User Story作成
User Story #3: CODEOWNERS設定
User Story #4: SemVer実践
```

#### 3. Git高度操作（60分）

**CODEOWNERS実践**:
- [ ] `.github/CODEOWNERS`ファイル作成
- [ ] チーム別の責務を定義
- [ ] PR作成時の自動アサイン確認

**SemVer実践**:
- [ ] `package.json`にバージョン設定（1.0.0）
- [ ] バグ修正 → PATCH更新（1.0.1）
- [ ] 機能追加 → MINOR更新（1.1.0）
- [ ] 破壊的変更 → MAJOR更新（2.0.0）
- [ ] Gitタグ作成: `git tag v1.0.0`
- [ ] タグプッシュ: `git push --tags`

**Commit規約**:
```bash
git commit -m "fixes AB#3: CODEOWNERS設定完了"
```

### 午後セッション（2-3時間）

#### 4. ブランチ戦略実践（90分）

**GitHub Flow実装**:
- [ ] `main`ブランチ保護設定
- [ ] `feature/AB#4-add-semver`ブランチ作成
- [ ] コード変更 → コミット → プッシュ
- [ ] PR作成 → レビュー → マージ
- [ ] GitHub Flow vs GitFlow vs Trunk-based比較

**Branch Protection設定**:
- [ ] Require pull request reviews
- [ ] Require status checks
- [ ] Require signed commits（オプション）

#### 5. Azure基礎インフラデプロイ（90分）

**Bicep実装**:
- [ ] Resource Group作成
- [ ] `infra/bicep/main.bicep`作成（Storage Account + App Service Plan）
- [ ] パラメータファイル作成（dev/staging/prod）
- [ ] デプロイ実行

```bash
# Resource Group作成
az group create --name rg-az400-handson --location japaneast

# Bicepデプロイ
az deployment group create \
  --resource-group rg-az400-handson \
  --template-file infra/bicep/main.bicep \
  --parameters infra/bicep/parameters/dev.parameters.json
```

### Day 1 成果物チェックリスト

- [ ] GitHub-Azure Boards統合完了
- [ ] AB#記法でWork Item連携確認
- [ ] CODEOWNERS動作確認
- [ ] SemVerでバージョン管理実践
- [ ] GitHub Flow実装
- [ ] Branch Protection設定完了
- [ ] 基本インフラ（Storage、App Service Plan）デプロイ完了

---

## 📅 Day 2: Azure Security（Key Vault/Managed Identity/App Insights）

**所要時間**: 5-7時間  
**目標**: Key Vault IAM理解、Managed Identity実装、App Insights統合、KQL実践

### 午前セッション（3-4時間）

#### 1. Key Vault実装（120分）

**Bicepコード作成**:
- [ ] `infra/bicep/modules/keyvault.bicep`作成
- [ ] Access Policiesでシークレット読み取り権限設定
- [ ] IAMで管理者権限設定（Key Vault Administratorロール）
- [ ] シークレット登録（例: DB接続文字列）

**重要な理解ポイント**:
```
Key Vault権限の2つのプレーン：

1. データプレーン（シークレット/キー/証明書の操作）
   → Access Policies で設定

2. 管理プレーン（Key Vault自体の作成/削除/設定変更）
   → IAM（RBAC）で設定

これを混同すると試験で確実に間違える！
```

**Copilotで確認**:
- "Key VaultのIAMとAccess Policiesの違いは？"
- "シークレットの読み取り権限を付与するには？"

#### 2. Managed Identity実装（90分）

**system-assigned実装**:
- [ ] `infra/bicep/modules/webapp.bicep`作成
- [ ] Web Appに system-assigned Managed Identity有効化
- [ ] Key VaultへのAccess Policy追加

**user-assigned実装（オプション）**:
- [ ] user-assigned Managed Identity作成
- [ ] 複数リソースで共有

**Copilotで確認**:
- "system-assignedとuser-assignedの使い分けは？"
- "どんな時にuser-assignedを選ぶべき？"

### 午後セッション（2-3時間）

#### 3. Application Insights統合（90分）

**Bicep実装**:
- [ ] `infra/bicep/modules/appinsights.bicep`作成
- [ ] Web AppにApplication Insights接続
- [ ] Instrumentation Key取得

**サンプルアプリ実装**:
- [ ] `src/webapp/app.js`にApp Insights SDK組み込み
- [ ] カスタムメトリクス送信
- [ ] Key Vaultからシークレット取得実装

```javascript
// app.js サンプル
const appInsights = require('applicationinsights');
const { DefaultAzureCredential } = require('@azure/identity');
const { SecretClient } = require('@azure/keyvault-secrets');

// App Insights初期化
appInsights.setup(process.env.APPLICATIONINSIGHTS_CONNECTION_STRING);
appInsights.start();

// Key Vaultからシークレット取得
const credential = new DefaultAzureCredential();
const vaultUrl = process.env.KEY_VAULT_URL;
const client = new SecretClient(vaultUrl, credential);
```

#### 4. KQL実践（60分）

**基本クエリ**:
```kql
// 1時間ごとのリクエスト数
requests
| where timestamp > ago(24h)
| summarize count() by bin(timestamp, 1h)
| render timechart

// 95パーセンタイルのレスポンスタイム
requests
| where timestamp > ago(1h)
| extend duration_ms = duration
| summarize percentile(duration_ms, 95) by bin(timestamp, 5m)

// エラー率
requests
| where timestamp > ago(1h)
| extend isError = toint(success == false)
| summarize errorRate = 100.0 * sum(isError) / count() by bin(timestamp, 5m)
```

**実践タスク**:
- [ ] `scripts/kql/basic-queries.kql`作成
- [ ] bin/extend/projectの違い理解
- [ ] パーセンタイルの意味理解

**Copilotで確認**:
- "95パーセンタイルのレスポンスタイムを取得するKQLは？"
- "extendとprojectの違いは？"

### Day 2 成果物チェックリスト

- [ ] Key Vault作成（Bicep）
- [ ] IAMとAccess Policies両方設定
- [ ] system-assigned Managed Identity実装
- [ ] WebアプリからKey Vault参照成功
- [ ] Application Insights統合完了
- [ ] カスタムメトリクス送信確認
- [ ] KQLクエリ実行成功（bin/extend/project）
- [ ] 95パーセンタイル計算理解

---

## 📅 Day 3: CI/CD完全マスター（GitHub Actions vs Azure Pipelines）

**所要時間**: 6-8時間  
**目標**: GitHub Actions実装、Azure Pipelines実装、両者の比較・使い分け理解

### 午前セッション（3-4時間）

#### 1. GitHub Actions実装（120分）

**CI Pipeline作成**:
- [ ] `.github/workflows/ci-github-actions.yml`作成
- [ ] ビルド、テスト、Dockerイメージ作成
- [ ] Azure Container Registryにプッシュ

```yaml
name: CI - GitHub Actions

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Install dependencies
        run: npm ci
        working-directory: ./src/webapp
      
      - name: Run tests
        run: npm test
        working-directory: ./src/webapp
      
      - name: Build Docker image
        run: |
          docker build -t az400webapp:${{ github.sha }} ./src/webapp
```

**CD Pipeline作成**:
- [ ] 環境別デプロイ（Dev → Staging → Prod）
- [ ] Azure/login設定（Service Principal）
- [ ] App Serviceへデプロイ

#### 2. セキュリティスキャン（60分）

**Dependabot設定**:
- [ ] `.github/dependabot.yml`作成
- [ ] npm、Docker、GitHub Actionsの依存関係スキャン

**Security Scan**:
- [ ] `.github/workflows/security-scan.yml`作成
- [ ] CodeQL分析設定

### 午後セッション（3-4時間）

#### 3. Azure Pipelines実装（120分）

**YAML Pipeline作成**:
- [ ] `.azure/pipelines/azure-pipelines.yml`作成
- [ ] 同じアプリを Azure Pipelines でもビルド
- [ ] Azure Artifacts統合

```yaml
trigger:
  branches:
    include:
      - main
      - develop

pool:
  vmImage: 'ubuntu-latest'

stages:
  - stage: Build
    jobs:
      - job: BuildJob
        steps:
          - task: NodeTool@0
            inputs:
              versionSpec: '18.x'
          
          - script: npm ci
            workingDirectory: src/webapp
            displayName: 'Install dependencies'
          
          - script: npm test
            workingDirectory: src/webapp
            displayName: 'Run tests'
```

**Branch Policy連携**:
- [ ] Azure DevOpsでBranch Policy設定
- [ ] Build validation必須化
- [ ] Work Item関連付け必須化

#### 4. 比較検証（90分）

**比較表作成**:
- [ ] パフォーマンス比較
- [ ] 機能比較
- [ ] コスト比較
- [ ] 使い分けガイドライン作成

**エージェント理解**:
- [ ] Microsoft-hostedの制限確認
- [ ] 並列ジョブの意味理解
- [ ] Self-hosted設定（オプション）

**Copilotで確認**:
- "この要件ならGitHub ActionsとAzure Pipelinesどちらを選ぶべき？"
- "並列ジョブの設定方法は？"

#### 5. 総合演習（60分）

**完全なDevOpsワークフロー実行**:
- [ ] Work Item作成（AB#20: 新機能追加）
- [ ] ブランチ作成（feature/AB#20-new-feature）
- [ ] コード変更 → コミット（fixes AB#20: 実装完了）
- [ ] PR作成 → CODEOWNERSによる自動アサイン
- [ ] CI実行（GitHub Actions / Azure Pipelines）
- [ ] レビュー → マージ
- [ ] CD実行（Dev → Staging → Prod）
- [ ] Application Insightsで動作確認
- [ ] Work Item自動クローズ確認

### Day 3 成果物チェックリスト

- [ ] GitHub Actions CI/CD動作確認
- [ ] Azure Pipelines CI/CD動作確認
- [ ] Dependabot設定完了
- [ ] CodeQL設定完了
- [ ] Branch Policy設定完了
- [ ] 環境別デプロイ実装
- [ ] GitHub Actions vs Azure Pipelines 比較表作成
- [ ] 完全なDevOpsワークフロー実行成功

---

## 🎓 学習完了後の確認ポイント

### 理解度チェック

以下の質問に即答できるか確認：

1. **Key Vault**: IAMとAccess Policiesの違いは？
2. **Managed Identity**: system-assignedとuser-assignedの使い分けは？
3. **Azure Boards**: Cycle TimeとLead Timeの違いは？
4. **SemVer**: バグ修正はどのバージョンを上げる？
5. **KQL**: 95パーセンタイルの意味は？
6. **CI/CD**: GitHub ActionsとAzure Pipelinesをどう使い分ける？
7. **ブランチ戦略**: GitHub Flowの特徴は？
8. **CODEOWNERS**: 配置場所は？

### 実践スキルチェック

以下を実際に実行できるか確認：

- [ ] Bicepで Key Vault + Managed Identity付きWeb App作成
- [ ] GitHub ActionsでCI/CDパイプライン作成
- [ ] Azure PipelinesでCI/CDパイプライン作成
- [ ] KQLで95パーセンタイルのレスポンスタイム取得
- [ ] Work Item連携したGitワークフロー実行
- [ ] SemVerに従ったバージョン管理

---

## 📚 補足リソース

### 公式ドキュメント
- [AZ-400 Skills Measured](https://learn.microsoft.com/certifications/exams/az-400)
- [Azure DevOps Labs](https://azuredevopslabs.com/)
- [GitHub Actions Documentation](https://docs.github.com/actions)
- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)

### 試験対策
- シラバス配分: **ビルド・リリースパイプライン 50-55%** ← 最重要
- 頻出ひっかけ: Key Vault権限、Cycle/Lead Time、CI/CD選択

---

**3日間の学習、頑張ってください！🚀**
