# GitHub Flow - 標準ワークフロー

このドキュメントは、GitHub FlowとAzure Boardsを統合した標準的な開発ワークフローの例です。

## 📋 事前準備

- Azure Boards Work Itemの番号を確認（例: AB#123）
- 変更する機能やファイルを明確化
- mainブランチが最新であることを確認

---

## 🔄 標準ワークフロー

### 1. mainから最新を取得

```bash
git checkout main
git pull origin main
```

### 2. feature ブランチを作成

**ブランチ命名規則**: `feature/AB#<Work-Item-ID>-<brief-description>`

```bash
# 例: Work Item AB#123 でインフラデプロイを実施する場合
git checkout -b feature/AB#123-infrastructure-deploy

# 他の例:
# git checkout -b feature/AB#456-add-authentication
# git checkout -b feature/AB#789-fix-api-bug
```

### 3. 変更をステージング

```bash
# 特定のファイル/ディレクトリを追加
git add <path/to/files>

# 例:
# git add infra/bicep/
# git add src/webapp/
# git add docs/
```

### 4. コミット（Conventional Commits + Azure Boards統合）

**コミットメッセージ形式**:
```
<type>: <短い説明>

<詳細説明（オプション）>
- 変更点1
- 変更点2

fixes AB#<Work-Item-ID>
```

**Type一覧**:
- `feat`: 新機能
- `fix`: バグ修正
- `docs`: ドキュメントのみの変更
- `style`: コードの意味に影響しない変更（フォーマット等）
- `refactor`: リファクタリング
- `test`: テスト追加・修正
- `chore`: ビルドプロセス、補助ツールの変更

**コミット例**:

```bash
git commit -m "feat: Bicepインフラコードを追加

- Storage Account, App Service Plan, Web App追加
- Managed Identity有効化
- Key Vault Access Policies設定
- Application Insights統合

fixes AB#123"

# 他の例:
# git commit -m "fix: API認証エラーを修正
# 
# - JWT検証ロジックを修正
# - エラーハンドリング改善
# 
# fixes AB#456"

# git commit -m "docs: セットアップ手順を更新
# 
# fixes AB#789"
```

### 5. feature ブランチにpush

```bash
git push origin feature/AB#123-infrastructure-deploy

# 他の例:
# git push origin feature/AB#456-add-authentication
```

### 6. Pull Request を作成

**方法1: GitHub CLI（推奨）**

```bash
gh pr create --title "feat: Bicepインフラコードを追加 (AB#123)" \
  --body "## 📋 概要
[変更内容の概要を記述]

## ✅ 主な変更点
- 変更点1
- 変更点2
- 変更点3

## 🔗 関連Work Item
fixes AB#123

## ✔️ チェックリスト
- [ ] コードレビュー完了
- [ ] テスト実施
- [ ] ドキュメント更新
- [ ] デプロイ確認（該当する場合）" \
  --base main
```

**方法2: GitHub Web UI**

1. GitHubリポジトリページに移動
2. "Compare & pull request" ボタンをクリック
3. タイトル: `<type>: <説明> (AB#<Work-Item-ID>)`
4. 説明欄にPRテンプレート内容を記入
5. "Create pull request" をクリック

---

## 📝 Pull Requestテンプレート

```markdown
## 📋 概要
[変更内容の簡潔な説明]

## ✅ 主な変更点
- 変更点1
- 変更点2
- 変更点3

## 🔗 関連Work Item
fixes AB#<Work-Item-ID>

## 🧪 テスト内容
- [ ] 単体テスト実施
- [ ] 統合テスト実施
- [ ] 手動テスト実施

## 📸 スクリーンショット（該当する場合）
[スクリーンショットまたはログを貼り付け]

## ✔️ チェックリスト
- [ ] コードレビュー完了
- [ ] CI/CDパイプライン成功
- [ ] ドキュメント更新
- [ ] セキュリティチェック完了
```

---

## 🎯 Azure Boards連携のポイント

### Work Item自動リンク

コミットメッセージやPR本文に以下を含めることで、自動的にWork Itemがリンクされます：

| 記法 | 効果 |
|------|------|
| `AB#123` | Work Itemへのリンク |
| `fixes AB#123` | PRマージ時にWork Itemを自動クローズ |
| `resolves AB#123` | PRマージ時にWork Itemを自動クローズ |
| `closes AB#123` | PRマージ時にWork Itemを自動クローズ |

### ブランチ命名のベストプラクティス

```bash
# 推奨パターン
feature/AB#123-short-description
bugfix/AB#456-fix-login-issue
hotfix/AB#789-critical-security-patch

# 非推奨パターン（避けるべき）
feature/new-feature  # Work Item番号なし
AB123  # typeなし
feature_AB_123  # スラッシュ区切りでない
```

---

## 🔄 完全なワークフロー例

```bash
# === 例: Bicepインフラデプロイ（Work Item AB#123） ===

# 1. 最新のmainを取得
git checkout main
git pull origin main

# 2. featureブランチ作成
git checkout -b feature/AB#123-bicep-infrastructure

# 3. ファイル編集（infra/bicep/以下のファイルを作成・編集）

# 4. ステージング
git add infra/bicep/

# 5. コミット
git commit -m "feat: Bicepインフラコードを追加

- Storage Account, App Service Plan, Web App
- Managed Identity有効化
- Key Vault with Access Policies
- Application Insights統合

fixes AB#123"

# 6. プッシュ
git push origin feature/AB#123-bicep-infrastructure

# 7. Pull Request作成
gh pr create --title "feat: Bicepインフラコードを追加 (AB#123)" \
  --body "## 📋 概要
Azure基本インフラのBicepコードを実装しました。

## ✅ 主な変更点
- Storage Account (汎用v2)
- App Service Plan (Linux, F1 Free tier)
- Web App (Node.js 18, Managed Identity有効)
- Key Vault (Access Policies設定)
- Application Insights

## 🔗 関連Work Item
fixes AB#123

## ✔️ チェックリスト
- [x] Bicepファイル作成
- [x] パラメータファイル作成（dev/staging/prod）
- [x] デプロイテスト完了
- [x] リソース動作確認" \
  --base main

# 8. レビュー後、mainにマージ（GitHub Web UIで実施）
# 9. ローカルのmainを更新
git checkout main
git pull origin main

# 10. featureブランチを削除（オプション）
git branch -d feature/AB#123-bicep-infrastructure
```

---

## 🚀 よくあるシナリオ

### シナリオ1: 複数ファイルを変更

```bash
git add src/webapp/app.js
git add src/webapp/package.json
git add docs/api.md
git commit -m "feat: REST API エンドポイント追加

- /api/users エンドポイント実装
- Express.js ルーティング設定
- APIドキュメント更新

fixes AB#200"
```

### シナリオ2: バグ修正

```bash
git checkout -b bugfix/AB#300-fix-login-error
# ファイル編集
git add src/auth/login.js
git commit -m "fix: ログイン時の認証エラーを修正

- JWT検証ロジック修正
- エラーハンドリング改善

fixes AB#300"
git push origin bugfix/AB#300-fix-login-error
```

### シナリオ3: ドキュメントのみ更新

```bash
git checkout -b docs/AB#400-update-readme
git add README.md
git commit -m "docs: READMEのセットアップ手順を更新

fixes AB#400"
git push origin docs/AB#400-update-readme
```

---

## 📚 参考リンク

- [GitHub Flow公式ガイド](https://docs.github.com/en/get-started/quickstart/github-flow)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Azure Boards GitHub統合](https://learn.microsoft.com/en-us/azure/devops/boards/github/)
- [AZ-400試験: ブランチ戦略](https://learn.microsoft.com/en-us/certifications/exams/az-400)