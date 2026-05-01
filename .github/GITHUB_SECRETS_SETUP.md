# GitHub Secrets設定ガイド

このガイドでは、GitHub ActionsワークフローでKey Vaultシークレットを設定するために必要なGitHub Secretsの設定方法を説明します。

## 📋 必要なシークレット一覧

### 1. Azure認証情報（必須）

#### `AZURE_CREDENTIALS`

Azure Service Principalの認証情報（JSON形式）

**取得方法:**

```bash
# Service Principalを作成
az ad sp create-for-rbac \
  --name "github-actions-az400" \
  --role contributor \
  --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID>/resourceGroups/rg-az400-handson \
  --sdk-auth
```

**出力例:**
```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

### 2. SQL Database設定（オプション）

Azure SQL Databaseを使用する場合のみ必要:

| シークレット名 | 説明 | 例 |
|-------------|------|------|
| `SQL_SERVER_FQDN` | SQL ServerのFQDN | `az400sqlserver.database.windows.net` |
| `SQL_DATABASE_NAME` | データベース名 | `az400db` |
| `SQL_ADMIN_USER` | 管理者ユーザー名 | `sqladmin` |
| `SQL_ADMIN_PASSWORD` | 管理者パスワード | `P@ssw0rd123!` |

**SQL Server FQDNの取得:**

```bash
az sql server show \
  --name az400-dev-sqlserver \
  --resource-group rg-az400-handson \
  --query fullyQualifiedDomainName -o tsv
```

### 3. その他のシークレット（オプション）

| シークレット名 | 説明 | 用途 |
|-------------|------|------|
| `API_KEY` | 外部APIキー | サードパーティAPI認証 |
| `EXTERNAL_API_TOKEN` | 外部APIトークン | Webhook認証など |

## 🔧 GitHub Secretsの設定手順

### 方法1: GitHub Web UI

1. GitHubリポジトリページに移動
2. **Settings** タブをクリック
3. 左メニューから **Secrets and variables** → **Actions** を選択
4. **New repository secret** をクリック
5. Name と Secret を入力
6. **Add secret** をクリック

### 方法2: GitHub CLI

```bash
# GitHub CLIでログイン
gh auth login

# シークレットを設定
gh secret set AZURE_CREDENTIALS < azure-credentials.json

gh secret set SQL_SERVER_FQDN -b "az400sqlserver.database.windows.net"
gh secret set SQL_DATABASE_NAME -b "az400db"
gh secret set SQL_ADMIN_USER -b "sqladmin"
gh secret set SQL_ADMIN_PASSWORD -b "P@ssw0rd123!"
gh secret set API_KEY -b "your-api-key-here"
```

### 方法3: セキュアな一括設定スクリプト

```powershell
# setup-github-secrets.ps1

# GitHub CLIがインストールされているか確認
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "❌ GitHub CLI がインストールされていません" -ForegroundColor Red
    Write-Host "https://cli.github.com/ からインストールしてください"
    exit 1
}

# ログイン確認
gh auth status
if ($LASTEXITCODE -ne 0) {
    Write-Host "GitHub CLIでログインしてください"
    gh auth login
}

Write-Host "🔐 GitHub Secrets を設定します" -ForegroundColor Green
Write-Host ""

# Azure Credentials（JSONファイルから）
$azureCredPath = Read-Host "Azure Credentials JSONファイルのパス"
if (Test-Path $azureCredPath) {
    gh secret set AZURE_CREDENTIALS < $azureCredPath
    Write-Host "✅ AZURE_CREDENTIALS を設定しました" -ForegroundColor Green
}

# SQL Server設定
$sqlServerFqdn = Read-Host "SQL Server FQDN (Enter でスキップ)"
if ($sqlServerFqdn) {
    gh secret set SQL_SERVER_FQDN -b $sqlServerFqdn
    Write-Host "✅ SQL_SERVER_FQDN を設定しました" -ForegroundColor Green
}

$sqlDbName = Read-Host "SQL Database名 (Enter でスキップ)"
if ($sqlDbName) {
    gh secret set SQL_DATABASE_NAME -b $sqlDbName
    Write-Host "✅ SQL_DATABASE_NAME を設定しました" -ForegroundColor Green
}

$sqlAdminUser = Read-Host "SQL管理者ユーザー名 (Enter でスキップ)"
if ($sqlAdminUser) {
    gh secret set SQL_ADMIN_USER -b $sqlAdminUser
    Write-Host "✅ SQL_ADMIN_USER を設定しました" -ForegroundColor Green
}

$sqlAdminPassword = Read-Host "SQL管理者パスワード (Enter でスキップ)" -AsSecureString
if ($sqlAdminPassword.Length -gt 0) {
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlAdminPassword)
    )
    gh secret set SQL_ADMIN_PASSWORD -b $plainPassword
    Write-Host "✅ SQL_ADMIN_PASSWORD を設定しました" -ForegroundColor Green
}

Write-Host ""
Write-Host "🔍 設定されたシークレット一覧:" -ForegroundColor Cyan
gh secret list

Write-Host ""
Write-Host "✅ GitHub Secrets の設定が完了しました！" -ForegroundColor Green
```

## 🔒 セキュリティベストプラクティス

### 1. Service Principalの権限を最小化

```bash
# Contributor の代わりに、必要な権限のみを付与
az role assignment create \
  --assignee <client-id> \
  --role "Key Vault Secrets Officer" \
  --scope /subscriptions/<sub-id>/resourceGroups/rg-az400-handson/providers/Microsoft.KeyVault/vaults/<kv-name>
```

### 2. シークレットのローテーション

定期的にシークレットを更新:

```bash
# 3ヶ月ごとに新しいClient Secretを生成
az ad sp credential reset \
  --id <client-id> \
  --append
```

### 3. 環境別のシークレット

GitHub Environmentsを使用して環境ごとにシークレットを分離:

1. Settings → Environments
2. "dev", "staging", "prod" 環境を作成
3. 各環境に異なるシークレットを設定

### 4. シークレットの監査

```bash
# Service Principalの使用状況を確認
az monitor activity-log list \
  --caller <client-id> \
  --max-events 50 \
  --output table
```

## ⚠️ トラブルシューティング

### シークレットが設定されない

```
Error: Could not create secret: Resource not accessible by integration
```

**解決策:**
- リポジトリの管理者権限があることを確認
- GitHub CLIで正しいリポジトリにログインしているか確認

### Service Principalの権限不足

```
AuthorizationFailed: The client does not have authorization to perform action
```

**解決策:**
```bash
# 権限を確認
az role assignment list --assignee <client-id> --output table

# 必要に応じて権限を追加
az role assignment create \
  --assignee <client-id> \
  --role "Contributor" \
  --scope /subscriptions/<sub-id>/resourceGroups/rg-az400-handson
```

## 📚 参考リンク

- [GitHub Actions のシークレット管理](https://docs.github.com/ja/actions/security-guides/encrypted-secrets)
- [Azure Service Principal 作成](https://learn.microsoft.com/ja-jp/azure/developer/github/connect-from-azure)
- [GitHub CLI ドキュメント](https://cli.github.com/manual/)
