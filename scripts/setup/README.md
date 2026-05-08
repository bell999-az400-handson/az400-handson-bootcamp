# セットアップスクリプト

このディレクトリには、Azure Key VaultとGitHub Secretsを安全に設定するためのスクリプトが含まれています。

## 📋 ファイル一覧

- `set-keyvault-secrets.sh` - Key Vaultシークレット設定スクリプト（Bash）
- `setup-github-secrets.ps1` - GitHub Secrets設定スクリプト（PowerShell）

## 🔐 セキュリティ機能

### このスクリプトの安全性

✅ **実装済みのセキュリティ対策:**

1. **パスワード非表示入力** - `read -sp` オプション使用
2. **履歴への記録防止** - `set +o history` で無効化
3. **メモリクリア** - 実行後に変数を `unset`
4. **デバッグモード無効** - `set +x` でパスワード表示を防止
5. **エラーハンドラー** - エラー時にシークレット値を表示しない
6. **出力抑制** - `--output none` でログに値を残さない

## 🚀 使用方法

### 前提条件

- Azure CLI インストール済み
- Azure にログイン済み (`az login`)
- Bicep デプロイ完了済み（Key Vault作成済み）

### ローカル実行

```bash
# 実行権限を付与
chmod +x scripts/setup/set-keyvault-secrets.sh

# 実行
./scripts/setup/set-keyvault-secrets.sh

# プロンプトに従ってパスワードを入力
```

### 環境変数を使用（オプション）

```bash
# 環境変数を設定
export RESOURCE_GROUP="rg-az400-handson"
export SQL_SERVER_NAME="az400-dev-sqlserver"
export SQL_DATABASE_NAME="az400db"
export SQL_ADMIN_USER="sqladmin"
export API_KEY="demo-api-key-12345-for-learning"

# 実行
./scripts/setup/set-keyvault-secrets.sh
```

### 実行後の確認

```bash
# シークレット一覧を確認（値は表示されない）
az keyvault secret list \
  --vault-name <your-keyvault-name> \
  --output table

# 特定のシークレット確認（値は表示されない）
az keyvault secret show \
  --vault-name <your-keyvault-name> \
  --name DatabaseConnectionString \
  --query "name"
```

## 🔒 セキュリティベストプラクティス

### ローカル実行時の注意事項

1. **実行後は履歴をクリア**
   ```bash
   history -c
   ```

2. **共有端末では使用しない**
   - 他のユーザーがアクセスできる環境では実行しない

3. **スクリプトのパーミッション確認**
   ```bash
   chmod 700 scripts/setup/set-keyvault-secrets.sh
   ```

### 本番環境での推奨方法

**本番環境では、GitHub Actions ワークフローを使用してください:**

1. GitHub Secretsにシークレットを設定
2. `.github/workflows/deploy-secrets.yml` を実行
3. 自動的にKey Vaultに設定される

詳細は `.github/workflows/README.md` を参照してください。

## 📝 設定されるシークレット

| シークレット名 | 説明 | 必須 |
|-------------|------|------|
| `DatabaseConnectionString` | SQL Database接続文字列（パスワード付き） | SQL Server存在時 |
| `DatabaseConnectionStringMI` | Managed Identity用接続文字列 | SQL Server存在時 |
| `ApiKey` | 外部APIキー | 環境変数設定時 |

## ⚠️ トラブルシューティング

### Key Vaultが見つからない

```
❌ Key Vaultが見つかりません
```

**解決策:**
1. Bicepデプロイが完了しているか確認
2. リソースグループ名が正しいか確認
3. デプロイメント名が "main" であることを確認

### SQL Serverが見つからない

```
⚠️ SQL Serverが見つかりません。スキップします。
```

**解決策:**
- SQL Serverが存在しない場合は問題ありません（スキップされます）
- SQL Server名とリソースグループ名が正しいか確認

### 権限エラー

```
Forbidden
```

**解決策:**
1. Azure CLIでログインしているアカウントを確認
   ```bash
   az account show
   ```

2. Key Vaultへのアクセス権限を確認
   ```bash
   az keyvault set-policy \
     --name <keyvault-name> \
     --upn <your-email> \
     --secret-permissions get list set
   ```

## 🔄 CI/CD統合

GitHub Actions での使用方法は、`.github/workflows/deploy-secrets.yml` を参照してください。

---

## 🔐 GitHub Secrets設定スクリプト

### setup-github-secrets.ps1

GitHub Secretsを対話的に設定するPowerShellスクリプトです。

#### 前提条件

- GitHub CLI (`gh`) インストール済み
- GitHub CLIでログイン済み (`gh auth login`)
- Azure Credentialsファイル作成済み（下記手順参照）

**Azure Credentialsファイルの作成**:

```powershell
# 1. サブスクリプションIDを取得
$SUBSCRIPTION_ID = az account show --query id -o tsv

# 2. サービスプリンシパルを作成してクリップボードにコピー（🔒 推奨）
az ad sp create-for-rbac `
  --name "github-actions-az400" `
  --role contributor `
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-az400-handson" `
  --sdk-auth | Set-Clipboard

Write-Host "✅ Azure認証情報をクリップボードにコピーしました" -ForegroundColor Green
Write-Host "⚠️ セキュリティ重要: ファイルに保存せず、直接GitHub Secretsに設定してください" -ForegroundColor Yellow
```

#### 使用方法

```powershell
# スクリプトを実行
cd scripts/setup
.\setup-github-secrets.ps1
```

#### セキュリティ機能

✅ **実装済みのセキュリティ対策:**

1. **クリップボード経由** - ファイルを作成せず、メモリ上で処理（🔒 最重要）
2. **自動クリア** - 設定後にクリップボードを自動的にクリア
3. **SecureString使用** - パスワード入力時にマスキング
4. **対話的入力** - コマンド履歴に残らない
5. **スキップ可能** - Enterキーで不要な項目をスキップ
6. **設定確認** - 最後に設定されたシークレット一覧を表示（値は非表示）

🚫 **絶対にしてはいけないこと:**
- JSONファイルをリポジトリに作成
- 認証情報をコミット
- パスワードをコマンド引数で渡す

#### 設定されるGitHub Secrets

| Secret名 | 説明 | 必須 |
|---------|------|------|
| `AZURE_CREDENTIALS` | Azureサービスプリンシパル（JSON） | ✅ |
| `SQL_SERVER_FQDN` | SQL Server完全修飾ドメイン名 | SQL使用時 |
| `SQL_DATABASE_NAME` | データベース名 | SQL使用時 |
| `SQL_ADMIN_USER` | SQL管理者ユーザー名 | SQL使用時 |
| `SQL_ADMIN_PASSWORD` | SQL管理者パスワード | SQL使用時 |
| `API_KEY` | 外部APIキー（学習用） | デモ値: `demo-api-key-12345-for-learning` |

#### 実行例

```powershell
PS> .\setup-github-secrets.ps1

🔐 GitHub Secrets を設定します

📋 ステップ1でクリップボードにコピーした Azure認証情報を使用します
クリップボードから設定しますか？ (y/n, Enter でスキップ): y
✅ AZURE_CREDENTIALS を設定しました
🔒 クリップボードをクリアしました

SQL Server FQDN (Enter でスキップ): az400-dev-sqlserver.database.windows.net
✅ SQL_SERVER_FQDN を設定しました

SQL Database名 (Enter でスキップ): az400db
✅ SQL_DATABASE_NAME を設定しました

SQL管理者ユーザー名 (Enter でスキップ): sqladmin
✅ SQL_ADMIN_USER を設定しました

SQL管理者パスワード (Enter でスキップ): ************
✅ SQL_ADMIN_PASSWORD を設定しました

🔍 設定されたシークレット一覧:
AZURE_CREDENTIALS  Updated 2026-05-05
SQL_SERVER_FQDN    Updated 2026-05-05
SQL_DATABASE_NAME  Updated 2026-05-05
SQL_ADMIN_USER     Updated 2026-05-05
SQL_ADMIN_PASSWORD Updated 2026-05-05

✅ GitHub Secrets の設定が完了しました！
```

#### トラブルシューティング

**GitHub CLIが見つからない**:
```
❌ GitHub CLI がインストールされていません
```

**解決策:**
```powershell
# Windows (winget)
winget install --id GitHub.cli

# または公式サイトからインストール
# https://cli.github.com/
```

**認証エラー**:
```powershell
# 再認証
gh auth logout
gh auth login
```

---

## 📚 関連ドキュメント

- [Day 2 ハンズオン資料](../../docs/handson/day2-azure-security.md)
- [GitHub Secrets設定ガイド](../../.github/GITHUB_SECRETS_SETUP.md)
- [GitHub Actions ワークフロー](../../.github/workflows/README.md)
- [Azure Key Vault ベストプラクティス](https://learn.microsoft.com/azure/key-vault/general/best-practices)
