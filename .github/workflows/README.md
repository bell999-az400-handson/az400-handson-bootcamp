# GitHub Actions ワークフロー

このディレクトリには、AZ-400ハンズオン用のGitHub Actionsワークフローが含まれています。

## 📋 ワークフロー一覧

### `deploy-secrets.yml`

Azure Key Vaultにシークレットを安全に設定するワークフロー

**トリガー:** 手動実行 (`workflow_dispatch`)

**用途:**
- GitHub Secretsから環境変数を注入
- Azure Key Vaultにシークレットを設定
- CI/CDパイプラインでの自動化

## 🚀 使用方法

### 1. GitHub Secretsの設定

リポジトリの Settings → Secrets and variables → Actions で以下を設定:

#### 必須シークレット

| シークレット名 | 説明 | 例 |
|-------------|------|------|
| `AZURE_CREDENTIALS` | Azure Service Principalの認証情報 | JSON形式 |

#### オプションシークレット（SQL Database使用時）

| シークレット名 | 説明 | 例 |
|-------------|------|------|
| `SQL_SERVER_FQDN` | SQL ServerのFQDN | `myserver.database.windows.net` |
| `SQL_DATABASE_NAME` | データベース名 | `az400db` |
| `SQL_ADMIN_USER` | SQL管理者ユーザー名 | `sqladmin` |
| `SQL_ADMIN_PASSWORD` | SQL管理者パスワード | `P@ssw0rd123!` |

#### その他のシークレット

| シークレット名 | 説明 | 例 |
|-------------|------|------|
| `API_KEY` | 外部APIキー | `sk-abc123...` |
| `EXTERNAL_API_TOKEN` | 外部APIトークン | `token_xyz789...` |

### 2. Azure Credentialsの取得

```bash
# Service Principalを作成
az ad sp create-for-rbac \
  --name "github-actions-az400" \
  --role contributor \
  --scopes /subscriptions/<subscription-id>/resourceGroups/rg-az400-handson \
  --sdk-auth

# 出力されたJSONをそのままGitHub Secretsの AZURE_CREDENTIALS に設定
```

出力例:
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

### 3. ワークフロー実行

1. GitHub リポジトリの **Actions** タブに移動
2. **Deploy Secrets to Key Vault** を選択
3. **Run workflow** をクリック
4. 環境を選択 (dev/staging/prod)
5. **Run workflow** を実行

## 🔒 セキュリティ機能

### このワークフローの安全性

✅ **実装済みのセキュリティ対策:**

1. **GitHub Secretsの使用**
   - すべてのシークレットは暗号化されて保存
   - ログに出力されない

2. **環境変数経由での注入**
   - ワークフローファイルに平文を含まない
   - `env:` ブロックで安全に受け渡し

3. **出力抑制**
   - `--output none` でシークレット値をログに残さない
   - 値は表示せず、設定完了メッセージのみ

4. **OIDC認証対応**
   - `permissions.id-token: write` で準備済み
   - パスワードレス認証への移行が可能

5. **環境別分離**
   - `environment` 機能で dev/staging/prod を分離
   - 環境ごとに異なるシークレットを設定可能

## 📝 カスタマイズ方法

### 新しいシークレットを追加

```yaml
- name: Set Custom Secret
  if: ${{ secrets.CUSTOM_SECRET != '' }}
  env:
    CUSTOM_SECRET: ${{ secrets.CUSTOM_SECRET }}
  run: |
    az keyvault secret set \
      --vault-name "${{ steps.get-kv.outputs.keyvault_name }}" \
      --name CustomSecretName \
      --value "$CUSTOM_SECRET" \
      --output none
    
    echo "✅ CustomSecretName を設定しました"
```

### リソースグループ名を変更

```yaml
- name: Get Key Vault Name
  id: get-kv
  run: |
    KEY_VAULT_NAME=$(az deployment group show \
      --resource-group ${{ vars.RESOURCE_GROUP }} \  # 変数を使用
      --name main \
      --query properties.outputs.keyVaultName.value -o tsv)
```

GitHub リポジトリの **Variables** で `RESOURCE_GROUP` を設定してください。

## ⚠️ トラブルシューティング

### Azure Login失敗

```
Error: Login failed
```

**解決策:**
1. `AZURE_CREDENTIALS` が正しく設定されているか確認
2. Service Principalがリソースグループへの権限を持っているか確認
   ```bash
   az role assignment list --assignee <client-id>
   ```

### Key Vault not found

```
ERROR: (ResourceNotFound) The Resource 'Microsoft.KeyVault/vaults/...' under resource group '...' was not found.
```

**解決策:**
1. Bicepデプロイが完了しているか確認
2. デプロイメント名が "main" であることを確認
3. リソースグループ名が正しいか確認

### Secrets not set

```
⚠️ シークレットがスキップされました
```

**解決策:**
- GitHub Secretsが設定されていない場合、該当ステップはスキップされます
- 必要なシークレットが設定されているか確認

## 🔄 ベストプラクティス

### 1. 環境別の設定

GitHub の **Environments** 機能を使用:

1. Settings → Environments で環境を作成
2. 各環境に異なるシークレットを設定
3. 承認ルールを設定（本番環境など）

### 2. シークレットのローテーション

定期的にシークレットを更新:

```bash
# 1. 新しいパスワードを生成
NEW_PASSWORD=$(openssl rand -base64 32)

# 2. GitHub Secretsを更新（手動）

# 3. ワークフローを実行して Key Vault に反映
```

### 3. 監査ログの確認

```bash
# Key Vault 操作ログを確認
az monitor activity-log list \
  --resource-group rg-az400-handson \
  --namespace Microsoft.KeyVault \
  --output table
```

## 📚 関連リンク

- [GitHub Actions でのシークレット管理](https://docs.github.com/ja/actions/security-guides/encrypted-secrets)
- [Azure Login Action](https://github.com/Azure/login)
- [Azure Key Vault ベストプラクティス](https://learn.microsoft.com/azure/key-vault/general/best-practices)
- [Day 2 ハンズオン資料](../docs/handson/day2-azure-security.md)
