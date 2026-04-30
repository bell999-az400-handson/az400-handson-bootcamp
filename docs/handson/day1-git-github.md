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

**⚠️ 重要**: 後のステップ（3.0）で CODEOWNERS を使用するため、**Organization 配下でリポジトリを作成することを強く推奨**します。

**推奨手順（Organization 配下で作成）**:

```bash
# 現在のディレクトリ確認
pwd
# 出力例: C:\Users\bell9\github\az400-handson-bootcamp

# Organization配下でリポジトリ作成（GitHub CLI使用）
# まず Organization を作成（Web UI または CLI）:
# Web UI: https://github.com/account/organizations/new
# Organization 名: az400-handson-org（または任意の名前）

# Organization 配下でリポジトリ作成
gh repo create az400-handson-org/az400-handson-bootcamp --public --source=. --remote=origin

# リモート追加（手動の場合）
git remote add origin https://github.com/az400-handson-org/az400-handson-bootcamp.git

# 初回Push
git branch -M main
git push -u origin main
```

**代替手順（個人アカウントで作成 → 後で Organization に移譲）**:

```bash
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

**注意**: 個人アカウントで作成した場合、ステップ 3.0 で Organization への移譲が必要になります。

**新規にリポジトリを作成する場合**:

```bash
# Organization 配下でリポジトリ作成後（Web UI または CLI）
git clone https://github.com/az400-handson-org/az400-handson-bootcamp.git
cd az400-handson-bootcamp

# このテンプレートリポジトリの内容をコピー
# （handson-bootcampフォルダの内容を新リポジトリにコピー）

# ※ 個人アカウントで作成した場合
git clone https://github.com/<your-github-username>/az400-handson-bootcamp.git
cd az400-handson-bootcamp
```

#### 1.2 Azure DevOpsプロジェクト作成

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

#### 3.0 GitHub Organization とチーム作成（準備）

**重要**: CODEOWNERS に記載される **@az400-admin や @infra-team などの "チーム" は GitHub Organization 内でのみ作成可能**です。個人リポジトリ単体では作れません。

##### 3.0.1 GitHub Organization の作成

**手順**:

1. GitHub の右上アイコンをクリック → **Your organizations** を選択
2. **New organization** をクリック
3. プランを選択:
   - **Free** を選択（個人学習用なら無料で十分）
4. Organization 名を入力:
   - 例: `az400-handson-org`（グローバルでユニークな名前が必要）
5. 連絡先メールアドレスを入力
6. **This organization belongs to:** で **My personal account** を選択
7. **Next** をクリック
8. （オプション）メンバー招待をスキップして **Complete setup** をクリック

**確認**: Organization URL: `https://github.com/az400-handson-org`

##### 3.0.2 既存リポジトリを Organization に移管（Transfer）

**重要**: ステップ 1.1 で個人アカウント配下にリポジトリを作成した場合、Organization に移管する必要があります。最初から Organization 配下で作成した場合は、このステップをスキップして 3.0.3 に進んでください。

**手順**:

1. GitHub で移動したいリポジトリ（`az400-handson-bootcamp`）を開く
2. 上部タブ → **Settings** をクリック
3. 左メニューを最下部までスクロール → **Danger Zone** セクションを表示
4. **Transfer ownership** の **Transfer** ボタンをクリック
5. ダイアログが表示されるので、以下を入力:
   - **New owner**: Organization 名を入力（例: `az400-handson-org`）
   - 確認用にリポジトリ名を再入力: `az400-handson-bootcamp`
6. **I understand, transfer this repository** をチェック
7. **Transfer this repository** ボタンをクリック

**確認**:
- リポジトリ URL が変更されます:
  - 変更前: `https://github.com/<your-username>/az400-handson-bootcamp`
  - 変更後: `https://github.com/az400-handson-org/az400-handson-bootcamp`
- Organization のリポジトリ一覧に表示されることを確認

**⚠️ ローカルリポジトリのリモート URL を更新**:

Transfer 後は、ローカルの Git 設定を更新する必要があります:

```bash
# 現在のリモート URL を確認
git remote -v
# 出力例: origin  https://github.com/<your-username>/az400-handson-bootcamp.git (fetch)

# リモート URL を Organization のものに変更
git remote set-url origin https://github.com/az400-handson-org/az400-handson-bootcamp.git

# 変更確認
git remote -v
# 出力例: origin  https://github.com/az400-handson-org/az400-handson-bootcamp.git (fetch)

# 接続テスト
git fetch
```

**よくあるつまずきポイント**:

| 問題 | 原因 | 解決方法 |
|------|------|----------|
| Transfer ボタンが見つからない | Danger Zone が表示されていない | ページを下までスクロールする |
| Organization 名の入力エラー | Organization が存在しない | 先に 3.0.1 で Organization を作成 |
| "You don't have permission" エラー | Organization のオーナーでない | Organization のオーナー権限を確認 |
| ローカルで git push できない | リモート URL が古いまま | `git remote set-url` でURLを更新 |

**Transfer のメリット**:
- ✅ CODEOWNERS でチーム指定が可能になる
- ✅ Organization レベルのセキュリティポリシーが適用される
- ✅ チームベースのアクセス管理が可能になる
- ✅ コミット履歴・Issue・PR は全て保持される

---

##### 3.0.2.1 Azure DevOps側でGitHub接続を再設定（重要）

**⚠️ リポジトリをOrganizationに移管した場合、Azure DevOps側でもGitHub接続の更新が必要です。**

リポジトリ移管後、Organization配下のリポジトリがAzure DevOpsに表示されない場合は、以下のいずれかの方法で対応してください。

---

**方法1: GitHub側でOAuth権限を承認（最も簡単）**

**手順**:

1. **GitHubにログイン** → 右上のアイコン → **Settings**

2. 左メニュー → **Applications** → **Authorized OAuth Apps** タブを選択

3. **Azure DevOps** または **Azure Boards** を探してクリック

4. **Organization access** セクションで、対象のOrganization（`az400-handson-org`）を確認:
   - ❌ **Request** または **Grant** ボタンが表示されている場合
     - **Request** をクリック（Organizationオーナーの場合は即座に承認される）
     - Organizationの別のオーナーがいる場合は承認を待つ
   
   - ✅ すでに **Granted** と表示されている場合
     - 権限は付与済み（方法2へ）

5. **Save** をクリック

6. Azure DevOpsに戻り、GitHub Connectionsページを **リロード**

7. リポジトリ選択画面でOrganization配下のリポジトリが表示されることを確認

---

**方法2: Azure DevOps側でGitHub接続を再作成**

権限を承認しても表示されない場合、接続を作り直します:

**手順（Azure DevOps側）**:

1. Azure DevOps → **Project Settings** → **GitHub connections**

2. 既存の接続があれば **Remove** （削除）

3. **Connect your GitHub account** をクリック

4. GitHubで認証（ポップアップが表示される）

5. **Organization access** の画面が表示された場合:
   - 対象のOrganization（`az400-handson-org`）の横の **Grant** をクリック
   - または **Request** をクリックして承認

6. 認証完了後、リポジトリ選択画面で **Organization配下のリポジトリ** が表示されることを確認

7. `az400-handson-org/az400-handson-bootcamp` を選択

8. **Save**

---

**方法3: GitHub App方式に切り替え（最新の推奨方法）**

Azure DevOpsは現在、**OAuth App** と **GitHub App** の2つの接続方式をサポートしています。GitHub Appの方が権限管理が明確です。

**手順**:

1. Azure DevOps → **Project Settings** → **GitHub connections**

2. **New connection** → **GitHub App** を選択（OAuth Appではなく）

3. **Install Azure Boards** をクリック

4. GitHubに遷移し、**Install on organization** を選択

5. Organization（`az400-handson-org`）を選択

6. **Repository access**:
   - **Only select repositories** を選択
   - `az400-handson-bootcamp` にチェック

7. **Install** をクリック

8. Azure DevOpsに戻り、接続が確立されたことを確認

---

**動作確認（AB#記法テスト）**:

接続完了後、AB#記法が機能するかテスト:

```bash
# テストコミット
echo "# GitHub Organization Transfer Test" >> docs/org-transfer-test.md
git add docs/org-transfer-test.md
git commit -m "test: Organization移管後の接続確認 AB#508"
git push origin main
```

**確認**:
- Azure DevOps → Boards → Work Item #508 を開く
- 「Development」セクションにコミットがリンクされていることを確認
- リンクされていればGitHub接続成功！

---

**よくあるトラブルシューティング**:

| 症状 | 原因 | 解決方法 |
|------|------|----------|
| Organizationが選択肢に出ない | OAuth権限未承認 | 方法1で権限承認 |
| 個人リポジトリしか表示されない | Organization権限がない | GitHub Settings > Applicationsで確認 |
| "Access denied" エラー | Organizationのオーナーでない | オーナーに権限承認を依頼 |
| リポジトリ一覧が空 | GitHub App未インストール | 方法3でGitHub Appをインストール |

---

##### 3.0.3 Organization 内でチームを作成

**手順**:

1. Organization ページで左メニュー → **Teams** をクリック
2. **New team** をクリック
3. 以下のチームを順番に作成:
   - `az400-admin`
   - `infra-team`
   - `webapp-team`
   - `devops-team`
   - `learning-team`

**各チーム作成時の設定**:

- **Team name**: 上記のチーム名を入力
- **Description**: （オプション）例: "Infrastructure team for Bicep code reviews"
- **Team visibility**: **Visible** を選択（デフォルト）
- **Create team** をクリック

##### 3.0.4 チームにメンバーを追加

**手順**（各チームで実施）:

1. 作成したチームを開く
2. **Members** タブ → **Add a member** をクリック
3. 自分の GitHub アカウントを追加

**ハンズオン用の簡略化**:
- 自分一人を全チーム（az400-admin、infra-team、webapp-team、devops-team、learning-team）に追加してOK
- 実務では役割に応じて異なるメンバーを配置

##### 3.0.5 チームにリポジトリへのアクセス権を付与

**重要**: CODEOWNERS が機能するには、チームがリポジトリにアクセスできる必要があります。

**前提**: 3.0.2 でリポジトリを Organization に移管済みであること

**手順**:

1. Organization ページ → **Repositories** → 対象リポジトリ（`az400-handson-bootcamp`）を選択
2. リポジトリの **Settings** → 左メニュー **Collaborators and teams** をクリック
3. **Add teams** をクリック
4. 各チームを追加し、権限レベルを設定:
   - `az400-admin`: **Maintain** または **Admin**
   - `infra-team`: **Write**
   - `webapp-team`: **Write**
   - `devops-team`: **Write**
   - `learning-team`: **Write**

**権限レベルの意味**:
- **Read**: 閲覧のみ
- **Write**: PR作成、レビュー、マージ可能
- **Maintain**: 設定変更可能（Issue/PR管理）
- **Admin**: 全権限

##### 3.0.6 CODEOWNERS の正しい記法

GitHub の Organization チームは **@organization-name/team-name** 形式で指定します。

**例**（Organization 名が `az400-handson-org` の場合）:

```
# インフラコード（Bicep）
/infra/bicep/**           @az400-handson-org/az400-admin @az400-handson-org/infra-team

# Webアプリケーション
/src/webapp/**            @az400-handson-org/webapp-team

# CI/CDパイプライン
/.github/workflows/**     @az400-handson-org/devops-team
/.azure/pipelines/**      @az400-handson-org/devops-team

# ドキュメント
/docs/**                  @az400-handson-org/learning-team
```

**⚠️ よくあるつまずきポイント（AZ-400 試験対策）**:

| 問題 | 原因 | 解決方法 |
|------|------|----------|
| チーム名だけ書いても動かない | `@team-name` では不十分 | `@org/team-name` 形式に修正 |
| "Team not found" エラー | Organization にチームが存在しない | Organization でチーム作成 |
| PR にレビュアーが自動アサインされない | チームにリポジトリ権限がない | Write 以上の権限を付与 |
| CODEOWNERS が無視される | ファイル配置場所が間違い | `.github/CODEOWNERS` または `/CODEOWNERS` に配置 |

**ハンズオン用推奨構成（卓さん向け）**:

```
Organization: az400-handson-org（または任意の名前）
├─ Teams:
│   ├─ az400-admin（あなた）
│   ├─ infra-team（あなた）
│   ├─ webapp-team（あなた）
│   ├─ devops-team（あなた）
│   └─ learning-team（あなた）
└─ Repository: az400-handson-bootcamp
    └─ 全チームに Write 権限付与
```

これで **実務に近い CODEOWNERS + Branch Protection Rules の演習** が可能になります。

---

#### 3.1 CODEOWNERS設定

**前提**: 上記 3.0 で Organization 作成、リポジトリ移管、チーム作成を完了していること

```bash
# Organization 名を変数に設定（実際の名前に置き換え）
ORG_NAME="az400-handson-org"

# ファイル作成
cat > .github/CODEOWNERS << EOF
# CODEOWNERS - AZ-400 ハンズオン用

# インフラコード（Bicep）
/infra/bicep/**           @${ORG_NAME}/az400-admin @${ORG_NAME}/infra-team

# Webアプリケーション
/src/webapp/**            @${ORG_NAME}/webapp-team

# CI/CDパイプライン
/.github/workflows/**     @${ORG_NAME}/devops-team
/.azure/pipelines/**      @${ORG_NAME}/devops-team

# ドキュメント
/docs/**                  @${ORG_NAME}/learning-team
EOF

git add .github/CODEOWNERS
git commit -m "fixes AB#3: CODEOWNERS設定完了"
git push origin main
```

**動作確認**:

1. ブランチ作成: `git checkout -b test-codeowners`
2. テストファイル作成:
   ```bash
   mkdir -p infra/bicep
   echo "// Test Bicep file" > infra/bicep/test.bicep
   git add infra/bicep/test.bicep
   git commit -m "test: CODEOWNERS動作確認用ファイル"
   git push origin test-codeowners
   ```
3. GitHub Web UI で PR 作成
4. PR の右サイドバー **Reviewers** セクションを確認:
   - `@az400-handson-org/az400-admin` と `@az400-handson-org/infra-team` が自動的にリクエストされていることを確認

**トラブルシューティング**:
- レビュアーが自動アサインされない場合:
  - チームにリポジトリの Write 権限があるか確認
  - CODEOWNERS のパス形式が正しいか確認（`/infra/bicep/**`）
  - Organization 名が正しいか確認（`@org/team`）

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

# 初期バージョンのタグ作成
git tag v1.0.0
git push origin v1.0.0
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
  name: '${resourcePrefix}${environmentName}${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false  // ⭐ セキュリティ: Blobパブリックアクセス無効化
    networkAcls: {
      defaultAction: 'Deny'  // ⭐ セキュリティ: デフォルト拒否
      bypass: 'AzureServices'
    }
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

**🔒 セキュリティチェックポイント**

デプロイ前に以下のセキュリティ設定を確認してください：

1. **Storage Account**
   - ✅ `minimumTlsVersion: 'TLS1_2'` - TLS 1.2以上を強制
   - ✅ `supportsHttpsTrafficOnly: true` - HTTPS通信のみ許可
   - ✅ `allowBlobPublicAccess: false` - パブリックアクセス無効化（推奨）
   - ✅ `networkAcls.defaultAction: 'Deny'` - ネットワークアクセス制限

2. **命名規則**
   - ✅ `uniqueString()` を使用してグローバルユニーク性を確保
   - リソース名の衝突を防止

3. **認証情報**
   - ✅ コード内に認証情報をハードコードしない
   - ✅ Key Vault使用（Day 2で実装予定）
   - ✅ Managed Identity使用（Day 2で実装予定）

---

```bash
az deployment group create \
  --resource-group rg-az400-handson \
  --template-file infra/bicep/main.bicep \
  --parameters infra/bicep/parameters/dev.parameters.json

# デプロイ確認
az resource list --resource-group rg-az400-handson --output table
```

**⚠️ よくあるデプロイエラーと解決方法**

実際のデプロイでは以下のエラーが発生する可能性があります：

---

**エラー 1: BCP080 循環依存エラー**

```
Error BCP080: The expression is involved in a cycle:
  'keyVault' -> 'webApp' -> 'keyVault'
```

**原因**: Key VaultがWeb AppのManaged Identity Principal IDを必要とし、Web AppがKey VaultのURIを必要とする循環参照

**解決方法**:

1. `infra/bicep/main.bicep` から `keyVaultUri` パラメータを削除:

```bicep
// ❌ 削除: keyVaultUri パラメータ
module webApp 'modules/webapp.bicep' = {
  name: 'webApp'
  params: {
    // keyVaultUri: keyVault.outputs.keyVaultUri  // 削除
  }
}
```

2. `infra/bicep/modules/webapp.bicep` から `keyVaultUri` パラメータ定義を削除

3. デプロイ順序を調整（webApp → keyVault の順）

---

**エラー 2: VM Quota超過エラー**

```
Code: SubscriptionIsOverQuotaForSku
Message: This region has quota of 0 instances for your subscription.
```

**原因**: サブスクリプションのVMクォータ不足（B1 BasicまたはF1 Free tier）

**解決方法**:

1. **F1 Free tierに変更** （推奨：無料枠内で実施可能）:

`infra/bicep/main.bicep` のApp Service Plan SKUを変更:

```bicep
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: '${resourcePrefix}-${environmentName}-asp'
  location: location
  sku: {
    name: 'F1'      // B1 → F1 に変更
    tier: 'Free'    // Basic → Free に変更
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}
```

2. **Quotaリクエストを提出**:

```bash
# Azure Portal > Subscriptions > Usage + quotas
# "Free Web App Hosting Plan" で検索してリクエスト
```

---

**エラー 3: Key Vault enablePurgeProtection エラー**

```
Code: BadRequest
Message: The property 'enablePurgeProtection' cannot be set to false.
```

**原因**: `enablePurgeProtection` は一度有効にすると無効化できない（Azure仕様）

**解決方法**:

`infra/bicep/modules/keyvault.bicep` から `enablePurgeProtection` プロパティを**完全に削除**:

```bicep
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    // enablePurgeProtection: false  // ← この行を削除
    accessPolicies: [
      // ...
    ]
  }
}
```

---

**エラー 4: alwaysOn not supported on F1 tier**

```
Code: BadRequest
Message: AlwaysOn cannot be set for this site as the plan does not allow it.
```

**原因**: F1 Free tierでは `alwaysOn` 機能がサポートされていない

**解決方法**:

`infra/bicep/modules/webapp.bicep` で `alwaysOn` を `false` に設定:

```bicep
resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: webAppName
  location: location
  properties: {
    serverFarmId: appServicePlanId
    siteConfig: {
      alwaysOn: false  // true → false に変更（F1 tier対応）
      linuxFxVersion: 'NODE|18-lts'
    }
  }
}
```

---

**最終的なデプロイ成功例**:

```bash
# 修正後のデプロイ実行
az deployment group create \
  --resource-group rg-az400-handson \
  --template-file infra/bicep/main.bicep \
  --parameters infra/bicep/parameters/dev.parameters.json

# 出力例:
# {
#   "properties": {
#     "provisioningState": "Succeeded",
#     "outputs": {
#       "storageAccountName": "az400devst",
#       "webAppName": "az400-dev-webapp",
#       "keyVaultName": "az400-dev-kv"
#     }
#   }
# }

# デプロイ確認
az resource list \
  --resource-group rg-az400-handson \
  --output table

# 出力例:
# Name                ResourceGroup        Type
# ------------------  -------------------  -----------------------------------------
# az400devst          rg-az400-handson     Microsoft.Storage/storageAccounts
# az400-dev-ai        rg-az400-handson     Microsoft.Insights/components
# az400-dev-asp       rg-az400-handson     Microsoft.Web/serverfarms
# az400-dev-webapp    rg-az400-handson     Microsoft.Web/sites
# az400-dev-kv        rg-az400-handson     Microsoft.KeyVault/vaults
```

**🎓 AZ-400試験対策ポイント**:

| エラー種別 | 試験での出題ポイント | 解決アプローチ |
|-----------|-------------------|--------------|
| **循環依存** | Bicepモジュール間の依存関係設計 | パラメータ削減、デプロイ順序調整 |
| **Quota超過** | リソースSKU選択、制限管理 | 無料枠活用、Quotaリクエスト |
| **不変プロパティ** | Key Vault設計の制約理解 | プロパティ削除、新規作成 |
| **SKU制限** | App Service Plan機能制限 | tierごとの機能比較表を暗記 |

---

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
