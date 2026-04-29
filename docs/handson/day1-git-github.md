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

#### 1.1 GitHubリポジトリ作成とPush

**前提**: ローカルに既に `az400-handson-bootcamp` リポジトリがある場合（このテンプレートをクローン済み）

```bash
# 現在のディレクトリ確認
pwd
# 出力例: C:\Users\bell9\github\az400-handson-bootcamp

# GitHubでリポジトリ作成（Web UIまたはGH CLI）
# 方法1: GitHub CLI使用
gh repo create az400-handson-bootcamp --public --source=. --remote=origin

# 方法2: Web UIで作成する場合
# 1. https://github.com/new にアクセス
# 2. Repository name: az400-handson-bootcamp
# 3. Public または Private を選択
# 4. "Create repository" をクリック
# 5. 作成後、以下のコマンドでリモート追加

git remote add origin https://github.com/<your-github-username>/az400-handson-bootcamp.git
# ↑ <your-github-username> を実際のGitHubユーザー名に置き換え（例: bell999）

# 初回Push
git branch -M main
git push -u origin main
```

**新規にリポジトリを作成する場合**:

```bash
# GitHubでリポジトリ作成後
git clone https://github.com/<your-github-username>/az400-handson-bootcamp.git
cd az400-handson-bootcamp

# テンプレートファイルをコピー（元のリポジトリから）
```

#### 1.2 Gitブランチをmainにリネーム（既にmasterの場合）

**既にブランチがmainの場合は、このステップをスキップしてください。**

既存のリポジトリでローカル・リモート両方のブランチが`master`の場合、以下の手順で`main`に変更します：

```bash
# ステップ1: ローカルブランチをmainに変更
git branch -m master main

# ステップ2: リモートにmainブランチをプッシュ
git push -u origin main

# ステップ3: リモートHEADをmainに変更
git remote set-head origin main

# ステップ4: GitHub CLIでデフォルトブランチを変更
gh repo edit <your-github-username>/az400-handson-bootcamp --default-branch main

# 方法4-2: GitHub Web UIで変更する場合
# 1. https://github.com/<your-github-username>/az400-handson-bootcamp/settings/branches を開く
# 2. ページ上部の「Default branch」セクションで切り替えアイコン（⇄）をクリック
# 3. ドロップダウンから「main」を選択
# 4. 「I understand, update the default branch」をクリック

# ステップ5: リモートのmasterブランチを削除
git push origin --delete master

# ステップ6: ローカルの参照を整理
git fetch --prune

# 確認
git branch -a
# 出力: * main
#       remotes/origin/HEAD -> origin/main
#       remotes/origin/main
```

**期待される結果**:
- ローカル: `main` のみ
- リモート: `origin/main` のみ（`origin/master` は削除済み）
- `origin/HEAD` が `origin/main` を指している

#### 1.3 Branch Protection設定（ブランチ保護）

GitHubで`main`ブランチに保護ルールを設定し、誤った操作を防ぎます。

**GitHub CLIで設定する場合**:

```bash
# ブランチ保護設定ページを開く
start https://github.com/<your-github-username>/az400-handson-bootcamp/settings/branch_protection_rules/new
# 例: start https://github.com/taku999/az400-handson-bootcamp/settings/branch_protection_rules/new
```

**Web UIで設定する場合**:

1. GitHub リポジトリページ > **Settings** > **Branches**
2. 「Branch protection rules」セクションで **Add rule** をクリック
3. 以下を設定：

**Branch name pattern（必須）**:
```
main
```

**Protect matching branches（保護ルール）**:

基本的な保護:
- ✅ **Require a pull request before merging** （PR必須）
  - **Require approvals**: `1` （最低1人の承認）
    - **注意**: GitHubの仕様上、`0`に設定することはできません
    - **1人で作業している場合**: 下記の「Do not allow bypassing」のチェックを外して管理者がバイパス可能にする
  - ✅ **Dismiss stale pull request approvals when new commits are pushed** （新コミット時に承認リセット）

推奨設定:
- ✅ **Require conversation resolution before merging** （コメント解決必須）
- ✅ **Do not allow bypassing the above settings** （管理者も保護ルールに従う）
  - **1人で作業している場合**: このチェックを外すと、管理者（リポジトリオーナー）はApprovalなしでPRをマージ可能

オプション（Day 3のCI/CD実装後に有効化推奨）:
- ⬜ **Require status checks to pass before merging** （CI/CDテスト成功必須）
  - パイプライン実装後に有効化
- ⬜ **Require linear history** （リベースのみ、マージコミット禁止）

4. ページ下部の **「Create」** ボタンをクリック

**設定完了の確認**:

```bash
# 試しにmainに直接pushしてみる（拒否されるはず）
echo "# Test" > test-protection.txt
git add test-protection.txt
git commit -m "test: branch protection test"
git push origin main
# 期待されるエラー: remote: error: GH006: Protected branch update failed
```

保護が有効な場合、以下のエラーが表示されます：
```
remote: error: GH006: Protected branch update failed for refs/heads/main.
```

これで、`main`への直接pushが禁止され、必ずPull Request経由でマージする必要があります。

**効果**:
- ✅ Force push禁止（履歴の破壊を防ぐ）
- ✅ ブランチ削除禁止
- ✅ 直接コミット禁止（PR必須）
- ✅ レビュー承認必須
- ✅ レビューコメント解決必須

**1人で作業している場合のPRマージ方法**:

**方法1: 管理者バイパスを有効化（推奨）**
1. 「Do not allow bypassing the above settings」の **チェックを外す**
2. PR作成後、GitHub Web UIで **「Merge without waiting for requirements to be met (bypass branch protections)」** を選択
3. 管理者権限でApprovalなしでマージ可能
4. 実務で管理者権限を持つ場合の動作を学習できる

**方法2: 別アカウントでApproval（チーム開発の練習）**
1. 別のGitHubアカウントをコラボレーターとして追加
2. そのアカウントでPRをApprove
3. 本番環境に近い運用を練習できる

**方法3: PR要件を緩和（非推奨：学習目的のみ）**
1. 「Require a pull request before merging」自体の **チェックを外す**
2. ブランチ保護は残るが、PRなしで直接mainにpush可能になる
3. 学習には不向きだが、テスト目的では選択肢になる

**AZ-400試験では「方法1」の動作理解が重要**:
- Q: "管理者がブランチ保護ルールをバイパスできるようにするには？"
- A: 「Do not allow bypassing the above settings」のチェックを外す

#### 1.4 Azure DevOpsプロジェクト作成

**既に README.md の手順でプロジェクトを作成済みの場合は、このステップをスキップしてください。**

1. https://dev.azure.com にアクセス
2. 「New Project」をクリック
3. プロジェクト名: `az400-handson`
4. Visibility: Private
5. Work item process: **Agile**（重要）
6. 「Create」をクリック

**確認**: プロジェクトURL: `https://dev.azure.com/<your-org>/az400-handson`

#### 1.5 ローカル環境確認

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

**既に README.md の手順で Work Items を作成済みの場合**:
- `scripts/setup/import-workitems.ps1` で66個のWork Itemsを作成済み
- `scripts/setup/link-workitems.ps1` で親子関係を設定済み
- このセクションはスキップして 2.2 に進んでください

**手動で作成する場合**: Azure DevOps で以下の Work Item を作成：

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
# README.mdが既にある場合は別のファイルで実施
echo "# AZ-400 Handson - Day 1" > docs/day1-progress.md
git add docs/day1-progress.md

# AB#の後にはあなたのEpic Work Item IDを指定
# import-workitems.ps1 を実行した場合、Epic ID は 508
git commit -m "fixes AB#508: Day 1開始"
git push origin main
```

**確認**:
- Azure DevOps > Boards > Work Items > Epic (ID: 508) を開く
- 「Development」セクションにコミットがリンクされていることを確認
- リンクされていない場合は、GitHub統合設定を確認

**AB#記法の構文**:
- `fixes AB#<ID>`: Work Itemを完了状態に移行
- `AB#<ID>`: Work Itemにリンクのみ（状態変更なし）

#### 2.4 Cycle Time vs Lead Time 理解

**確認場所**: Azure DevOps Web UI > **Overview > Dashboards**

**操作手順**:
1. https://dev.azure.com/<your-org>/az400-handson にアクセス
2. 左サイドバーから **Overview** をクリック
3. サブメニューから **Dashboards** を選択
4. 既存のダッシュボードを開くか、**+ New Dashboard** で新規作成
5. **Add a widget** をクリック
6. ウィジェットギャラリーで **"Cycle Time"** または **"Lead Time"** を検索
7. ウィジェットを選択して **Add** をクリック
8. ウィジェット設定で対象のWork Itemタイプ（User Story、Task等）を選択
9. **時間範囲（Time period）** を設定:
   - **推奨**: **"Rolling period"** > **"Last 30 days"** を選択
   - **注意**: 期間は **最低14日間以上** 必要です
   - **手動設定する場合**: Start dateとEnd dateの差を14日以上にする
   - **エラー例**: "14 days is the minimum allowable time period." → 期間を延長してください
10. グラフで可視化されたCycle Time/Lead Timeを確認

**⚠️ よくあるエラーと解決方法**:

**エラー**: `14 days is the minimum allowable time period.`

**原因**: Start dateとEnd dateの期間が14日未満

**解決方法**:
```
❌ NG: 2026/04/20 ～ 2026/04/29 (10日間)
✅ OK: 2026/04/15 ～ 2026/04/29 (15日間)
✅ 推奨: "Last 30 days" を選択（自動で過去30日間）
```

**なぜ14日間が最小なのか**:
- Cycle Time/Lead Timeは **トレンド分析** のためのメトリクス
- 短期間では統計的に意味のある傾向が見えない
- 最低14日間のデータでパターンを把握するのがベストプラクティス

**Analytics viewsとの違い**:
- **Analytics views**: データソースの定義（どのWork Itemを分析するか）
- **Dashboards**: 実際の可視化・グラフ表示（Cycle Time/Lead Timeウィジェットを配置）

**🤖 自動追跡の仕組み（重要）**:

**手動で時間を入力する必要はありません！** Work Itemの **State（状態）** を変更するだけで、Azure DevOpsが自動的にタイムスタンプを記録し、Cycle Time/Lead Timeを計算します。

**必要な操作**:
- ✅ Work Itemの状態を変更する（New → Active → Closed）
- ❌ 開始時間・終了時間を手動入力（不要）

**自動記録されるフィールド**:
- `System.CreatedDate`: Work Item作成日時
- `Microsoft.VSTS.Common.ActivatedDate`: Active状態になった日時
- `Microsoft.VSTS.Common.ClosedDate`: Closed状態になった日時

これらのタイムスタンプから、自動的にCycle Time/Lead Timeが計算されます。

**実践例**:
```
1. Work Item作成 → "New" (2026/04/29 09:00 自動記録)
   ↓
2. 作業開始 → "Active" に変更 (2026/04/29 10:00 自動記録)
   ↓
3. 完了 → "Closed" に変更 (2026/04/30 15:00 自動記録)
   ↓
4. 自動計算:
   - Cycle Time = 29時間（Active → Closed）
   - Lead Time = 30時間（New → Closed）
```

**概念**:

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
- "Cycle Time/Lead Timeを可視化する場所" = Dashboards（Analytics viewsではない）

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

#### 4.1 Branch Protection詳細設定（オプション）

**既にステップ 1.3 でBranch Protection基本設定を完了している場合は、このステップをスキップするか、CI/CD実装後に追加設定してください。**

GitHub > Settings > Branches > 既存のルールを編集:

CI/CD実装後の追加設定（Day 3以降）:
- ✅ **Require status checks to pass before merging** （CI/CDテスト成功必須）
  - Status checks: テスト、ビルド、Lintなど
  - ✅ **Require branches to be up to date before merging** （最新状態必須）

その他の高度な設定:
- ✅ **Require linear history** （リベースのみ、マージコミット禁止）
- ✅ **Require deployments to succeed before merging** （デプロイ成功必須）
- ⬜ **Lock branch** （読み取り専用にする）

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
