# Day 1: Git/GitHub高度操作 + Azure基礎

> **所要時間**: 4-6時間  
> **目標**: GitHub-Azure DevOps統合、Git高度操作、基本インフラデプロイ

## 🎯 学習目標

- Azure Boards と GitHub の統合を実装
- CODEOWNERS の動作を理解
- SemVer（セマンティックバージョニング）を実践
- ブランチ戦略（GitHub Flow）を実装
- Bicep で基本インフラをデプロイ
- AB#記法による Work Item 連携を確認

---

## ✅ 前提条件

- Azure サブスクリプション
- Azure DevOps 組織
- GitHub アカウント
- ローカル環境:
  - Git
  - Azure CLI (`az`)
  - Node.js 18+
  - VS Code（推奨）

---

## 📋 午前セッション（2-3時間）

### ステップ 1: 環境セットアップ（30分）

#### 1.1 GitHubリポジトリ作成

```bash
# GitHubでリポジトリ作成（Web UIまたはGH CLI）
gh repo create az400-handson-bootcamp --public

# クローン
git clone https://github.com/<your-username>/az400-handson-bootcamp.git
cd az400-handson-bootcamp

# このテンプレートリポジトリの内容をコピー
# （handson-bootcampフォルダの内容を新リポジトリにコピー）
```

#### 1.2 Azure DevOpsプロジェクト作成

1. https://dev.azure.com にアクセス
2. 「New Project」をクリック
3. プロジェクト名: `AZ400-Handson`
4. Visibility: Private
5. Work item process: **Agile**（重要）
6. 「Create」をクリック

#### 1.3 ローカル環境確認

```bash
# Azureログイン
az login
az account show

# Gitバージョン確認
git --version

# Node.jsバージョン確認
node --version  # v18以上
npm --version
```

---

### ステップ 2: Azure Boards統合（45分）

#### 2.1 Work Item作成

Azure DevOps で以下の Work Item を作成：

```
Epic #1: AZ-400ハンズオン環境構築
  ├─ Feature #2: Git/GitHub基礎実装
  │   ├─ User Story #3: CODEOWNERS設定
  │   ├─ User Story #4: SemVer実践
  │   └─ User Story #5: GitHub Flow実装
  │
  ├─ Feature #6: Azure基礎インフラ
  │   └─ User Story #7: Bicepで基本リソースデプロイ
  │
  └─ Feature #8: セキュリティ実装（Day 2用）
```

**作成手順**:

1. Azure DevOps > Boards > Work Items
2. 「New Work Item」> 「Epic」
3. Title: `AZ-400ハンズオン環境構築`
4. Description: `3日間でAZ-400試験対策の実践環境を構築`
5. 「Save」

同様に Feature、User Story を作成

#### 2.2 GitHub統合設定

1. Azure DevOps > Project Settings > GitHub connections
2. 「Connect your GitHub account」
3. GitHubで認証
4. リポジトリ選択: `az400-handson-bootcamp`
5. 「Save」

#### 2.3 AB#記法テスト

```bash
# テストコミット
echo "# AZ-400 Handson" > README.md
git add README.md
git commit -m "fixes AB#1: プロジェクト初期化"
git push origin main
```

**確認**:
- Azure DevOps > Boards > Work Items > Epic #1 を開く
- 「Development」セクションにコミットがリンクされていることを確認

#### 2.4 Cycle Time vs Lead Time 理解

**Cycle Time**: 作業開始（Active）→ 完了（Done）までの時間
**Lead Time**: 作成（New）→ 完了（Done）までの時間

```
New → Active → Resolved → Closed
 |←  Lead Time  →|
      |← Cycle Time →|
```

**試験ひっかけポイント**:
- "作業開始から完了まで" = Cycle Time
- "作成から完了まで" = Lead Time

---

### ステップ 3: Git高度操作（60分）

#### 3.1 CODEOWNERS設定

```bash
# ファイル作成
cat > .github/CODEOWNERS << 'EOF'
# CODEOWNERS - AZ-400 ハンズオン用

# インフラコード（Bicep）
/infra/bicep/**           @az400-admin @infra-team

# Webアプリケーション
/src/webapp/**            @webapp-team

# CI/CDパイプライン
/.github/workflows/**     @devops-team
/.azure/pipelines/**      @devops-team

# ドキュメント
/docs/**                  @learning-team
EOF

git add .github/CODEOWNERS
git commit -m "fixes AB#3: CODEOWNERS設定完了"
git push origin main
```

**動作確認**:
1. ブランチ作成: `git checkout -b test-codeowners`
2. `infra/bicep/test.bicep` を作成
3. Push して PR 作成
4. PR に自動的にレビュアーがアサインされることを確認

#### 3.2 SemVer実践

**package.json作成**:

```bash
cd src/webapp
npm init -y

# package.jsonを編集
cat > package.json << 'EOF'
{
  "name": "az400-webapp",
  "version": "1.0.0",
  "description": "AZ-400 Handson Web Application",
  "main": "app.js",
  "scripts": {
    "start": "node app.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "keywords": ["az400", "devops"],
  "author": "",
  "license": "MIT"
}
EOF

git add src/webapp/package.json
git commit -m "fixes AB#4: 初期バージョン1.0.0設定"
```

**SemVer理解**:

| 変更種別 | バージョン | 例 |
|---------|-----------|-----|
| 破壊的変更（Breaking Change） | Major | 1.0.0 → 2.0.0 |
| 機能追加（後方互換） | Minor | 1.0.0 → 1.1.0 |
| バグ修正 | Patch | 1.0.0 → 1.0.1 |

**実践**:

```bash
# バグ修正 → PATCH
# package.json の version を 1.0.1 に変更
git commit -am "fix: バグ修正（AB#4）"
git tag v1.0.1
git push origin v1.0.1

# 機能追加 → MINOR
# package.json の version を 1.1.0 に変更
git commit -am "feat: 新機能追加（AB#4）"
git tag v1.1.0
git push origin v1.1.0
```

**試験ひっかけポイント**:
- Q: "バグ修正を含むリリースです。11.2.0の次は？"
- A: 11.2.1（PATCH を上げる）

---

## 📋 午後セッション（2-3時間）

### ステップ 4: ブランチ戦略実践（90分）

#### 4.1 Branch Protection設定

GitHub > Settings > Branches > Add rule:

- Branch name pattern: `main`
- ✅ Require pull request reviews before merging
- ✅ Require status checks to pass before merging
- ✅ Require conversation resolution before merging
- ✅ Do not allow bypassing the above settings

#### 4.2 GitHub Flow実装

```bash
# User Story #5: GitHub Flow実装
# 1. feature ブランチ作成
git checkout main
git pull
git checkout -b feature/AB#5-github-flow

# 2. 変更
echo "# GitHub Flow Practice" >> docs/github-flow.md
git add docs/github-flow.md
git commit -m "docs: GitHub Flow実践ドキュメント追加（AB#5）"

# 3. Push
git push origin feature/AB#5-github-flow

# 4. PR作成（GitHub Web UIで）
# 5. レビュー → マージ
```

#### 4.3 ブランチ戦略比較

| 戦略 | 特徴 | 適用ケース |
|------|------|-----------|
| **GitHub Flow** | main のみ、PR→本番デプロイ→マージ | 継続的デプロイ、Web アプリ |
| **Git Flow** | main/develop 分離、リリースブランチ | 計画的リリース、パッケージ |
| **Trunk-based** | main に直接コミット | 高頻度デプロイ、フィーチャーフラグ |

**試験ひっかけポイント**:
- Q: "PR を本番にデプロイしてからマージ" = **GitHub Flow**
- Q: "develop ブランチで開発" = **Git Flow**

---

### ステップ 5: Azure基礎インフラデプロイ（90分）

#### 5.1 Resource Group作成

```bash
az group create \
  --name rg-az400-handson \
  --location japaneast
```

#### 5.2 Bicepファイル作成

**infra/bicep/main.bicep**:

```bicep
targetScope = 'resourceGroup'

@description('環境名（dev/staging/prod）')
param environmentName string = 'dev'

@description('ロケーション')
param location string = resourceGroup().location

@description('リソース名のプレフィックス')
param resourcePrefix string = 'az400'

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${resourcePrefix}${environmentName}storage'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: '${resourcePrefix}-${environmentName}-asp'
  location: location
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

output storageAccountName string = storageAccount.name
output appServicePlanName string = appServicePlan.name
```

**infra/bicep/parameters/dev.parameters.json**:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environmentName": {
      "value": "dev"
    },
    "resourcePrefix": {
      "value": "az400"
    }
  }
}
```

#### 5.3 デプロイ実行

```bash
az deployment group create \
  --resource-group rg-az400-handson \
  --template-file infra/bicep/main.bicep \
  --parameters infra/bicep/parameters/dev.parameters.json

# デプロイ確認
az resource list --resource-group rg-az400-handson --output table
```

#### 5.4 Commit & Push

```bash
git add infra/bicep/
git commit -m "fixes AB#7: 基本インフラ（Storage、App Service Plan）デプロイ完了"
git push origin main
```

---

## ✅ Day 1 成果物チェックリスト

### GitHub統合
- [ ] GitHubリポジトリ作成完了
- [ ] Azure DevOpsプロジェクト作成完了
- [ ] GitHub-Azure Boards統合設定完了
- [ ] AB#記法でWork Item連携確認

### Git高度操作
- [ ] CODEOWNERS作成・動作確認
- [ ] SemVerでバージョン管理実践
- [ ] Gitタグ作成・プッシュ

### ブランチ戦略
- [ ] Branch Protection設定完了
- [ ] GitHub Flow実装
- [ ] PR作成→レビュー→マージの流れ確認

### インフラ
- [ ] Resource Group作成
- [ ] Bicepで Storage Account デプロイ
- [ ] Bicepで App Service Plan デプロイ
- [ ] パラメータファイル作成（dev）

### 理解度確認

以下の質問に即答できるか確認：

1. **Cycle TimeとLead Timeの違いは？**
   - Answer: Cycle Time = 作業開始→完了、Lead Time = 作成→完了

2. **バグ修正はSemVerのどれを上げる？**
   - Answer: PATCH（例: 1.2.3 → 1.2.4）

3. **CODEOWNERSファイルの配置場所は？**
   - Answer: .github/CODEOWNERS

4. **GitHub Flowの特徴は？**
   - Answer: PR→本番デプロイ→mainマージ

---

## 🎓 試験対策ポイント

### Day 1で克服した弱点領域

✅ **SemVer理解**  
✅ **CODEOWNERS配置場所**  
✅ **ブランチ戦略の適用判断**  
✅ **Azure Boards KPI（Cycle/Lead Time）**

### 次のステップ

明日（Day 2）は **Azure Security** を実践します：
- Key Vault IAM vs Access Policies
- Managed Identity（system/user-assigned）
- Application Insights & KQL

---

**Day 1お疲れ様でした！明日も頑張りましょう！🚀**
