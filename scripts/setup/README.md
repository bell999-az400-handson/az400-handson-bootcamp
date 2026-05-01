# Key Vault シークレット設定スクリプト

このディレクトリには、Azure Key Vaultにシークレットを安全に設定するためのスクリプトが含まれています。

## 📋 ファイル一覧

- `set-keyvault-secrets.sh` - Key Vaultシークレット設定スクリプト（Bash）

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
export API_KEY="your-api-key-here"

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

## 📚 関連ドキュメント

- [Day 2 ハンズオン資料](../../docs/handson/day2-azure-security.md)
- [GitHub Actions ワークフロー](../../.github/workflows/README.md)
- [Azure Key Vault ベストプラクティス](https://learn.microsoft.com/azure/key-vault/general/best-practices)
