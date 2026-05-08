# Day 2: Azure Security（Key Vault/Managed Identity/App Insights)

> **所要時間**: 5-7時間  
> **目標**: Key Vault IAM理解、Managed Identity実装、App Insights統合、KQL実践

## 🎯 学習目標

- **Key Vault IAM vs Access Policies** の違いを完全理解（最重要）
- **system-assigned vs user-assigned Managed Identity** の使い分け
- WebアプリからKey Vaultのシークレット取得
- Application Insights統合とカスタムメトリクス送信
- KQLクエリ実践（bin/extend/project/percentile）

---

## ✅ 前提条件

- Day 1 完了（基本インフラデプロイ済み）
- Azure CLI ログイン済み
- VS Code + Bicep extension

---

## 📋 午前セッション（3-4時間）

### ステップ 1: Key Vault実装（120分）

#### 1.1 Key Vault IAM vs Access Policies 理解

**最重要概念**:

```
Azure Key Vaultには2つの権限プレーンがある：

1️⃣ データプレーン（Data Plane）
   → シークレット/キー/証明書の読み書き操作
   → 設定方法: Access Policies

2️⃣ 管理プレーン（Management Plane）
   → Key Vault自体の作成/削除/設定変更
   → 設定方法: IAM（RBAC）

試験で最も間違えやすいポイント！
```

| 操作 | 使用するプレーン | 設定方法 |
|------|----------------|---------|
| シークレット取得 | データプレーン | Access Policies |
| シークレット設定 | データプレーン | Access Policies |
| Key Vault作成 | 管理プレーン | IAM |
| Key Vault削除 | 管理プレーン | IAM |
| タグ追加 | 管理プレーン | IAM |

#### 1.2 Bicepコード作成

**infra/bicep/modules/keyvault.bicep**:

```bicep
@description('Key Vault名')
param keyVaultName string

@description('ロケーション')
param location string = resourceGroup().location

@description('テナントID')
param tenantId string = subscription().tenantId

@description('Managed IdentityのオブジェクトID（Access Policy用）')
param managedIdentityObjectId string = ''

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
    enableRbacAuthorization: false  // Access Policies使用
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    
    // データプレーン権限: Access Policies
    accessPolicies: [
      {
        tenantId: tenantId
        objectId: managedIdentityObjectId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
    
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
```

**重要ポイント**:
- `enableRbacAuthorization: false` → Access Policies使用
- `accessPolicies` → データプレーン権限（シークレット読み取り）
- IAM（管理プレーン）は Azure Portal または Bicep の roleAssignment で設定
- **🔒 シークレット値はBicepにハードコードしない**（後述の手順で安全に設定）

#### 1.3 IAM設定（管理プレーン）

**Key Vault Administratorロール付与（Bicep）**:

```bicep
// 管理プレーン権限: IAM（RBAC）
var keyVaultAdministratorRole = '00482a5a-887f-4fb3-b363-3b7fe8e74483'

resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, managedIdentityObjectId, keyVaultAdministratorRole)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultAdministratorRole)
    principalId: managedIdentityObjectId
    principalType: 'ServicePrincipal'
  }
}
```

#### 1.4 シークレットの安全な設定（重要）

**🔒 セキュリティベストプラクティス**:

```powershell
# ❌ NG例: Bicepファイルにシークレット値をハードコード（絶対禁止）
# resource secret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
#   properties: { value: 'my-secret-password-123' }  // 🚫 危険！
# }

# ✅ OK例: デプロイ後にAzure CLIで安全に設定
```

**手順1: Key Vaultデプロイ（シークレットなし）**

```powershell
# Bicepデプロイ（シークレット値は含まない）
az deployment group create `
  --resource-group rg-az400-handson `
  --template-file infra/bicep/main.bicep `
  --parameters infra/bicep/parameters/dev.parameters.json

# Key Vault名を取得
$KEY_VAULT_NAME = az deployment group show `
  --resource-group rg-az400-handson `
  --name main `
  --query properties.outputs.keyVaultName.value -o tsv

Write-Host "Key Vault名: $KEY_VAULT_NAME"
```

**手順2: Web AppにKEY_VAULT_URL環境変数を設定（Bicep優先）**

Web Appが`app.js`内でKey Vaultに接続するには、環境変数`KEY_VAULT_URL`が必要です。

**⚠️ 循環依存の問題と解決策**

通常のパラメータ渡しでは循環依存が発生します：
- Web App → Key Vault URL が必要
- Key Vault → Web AppのManaged Identity Object ID が必要

**解決策: 段階的デプロイ**

`infra/bicep/main.bicep`で、Key Vaultデプロイ後にWeb Appの設定を更新：

```bicep
// 1. Web App（Managed Identity付き） - 初回デプロイ
module webApp 'modules/webapp.bicep' = {
  name: 'webAppDeployment'
  params: {
    webAppName: '${resourcePrefix}-${environmentName}-webapp'
    appServicePlanId: appServicePlan.id
    location: location
    appInsightsConnectionString: appInsights.outputs.connectionString
    // KEY_VAULT_URLはまだ設定しない
  }
}

// 2. Key Vault - Web AppのManaged Identityを使用
module keyVault 'modules/keyvault.bicep' = {
  name: 'keyVaultDeployment'
  params: {
    keyVaultName: '${resourcePrefix}-${environmentName}-kv'
    location: location
    managedIdentityObjectId: webApp.outputs.managedIdentityPrincipalId
  }
}

// 3. Web AppにKEY_VAULT_URL環境変数を追加（Key Vaultデプロイ後）
resource webAppConfig 'Microsoft.Web/sites/config@2023-01-01' = {
  name: '${webApp.outputs.webAppName}/appsettings'
  properties: {
    WEBSITES_ENABLE_APP_SERVICE_STORAGE: 'false'
    DOCKER_ENABLE_CI: 'true'
    APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights.outputs.connectionString
    KEY_VAULT_URL: keyVault.outputs.keyVaultUri  // ← ここで追加
    PORT: '3000'
  }
}
```

**⚠️ 注意**: 上記はコンセプト説明用です。実際のmain.bicepでは`name`プロパティで`'${resourcePrefix}-${environmentName}-webapp/appsettings'`を使用します（モジュールoutputは名前に使えないため）。

**方法1: Bicep自動設定（推奨）**

```powershell
# 1回のデプロイで全て設定される
az deployment group create `
  --resource-group rg-az400-handson `
  --template-file infra/bicep/main.bicep `
  --parameters infra/bicep/parameters/dev.parameters.json

# デプロイ完了後、KEY_VAULT_URLが自動設定される
```

**確認**

```powershell
$WEBAPP_NAME = az webapp list -g rg-az400-handson --query "[0].name" -o tsv

# KEY_VAULT_URL環境変数の確認
az webapp config appsettings list `
  --name $WEBAPP_NAME `
  --resource-group rg-az400-handson `
  --query "[?name=='KEY_VAULT_URL'].{Name:name, Value:value}" -o table

# 期待される出力:
# Name            Value
# --------------  --------------------------------------------------
# KEY_VAULT_URL   https://az400-dev-kv-xxxxx.vault.azure.net/
```

**方法2: Azure CLI手動設定（Bicepデプロイ前の場合）**

既にデプロイ済みで、Bicepを再デプロイしたくない場合：

```powershell
# リソース名を取得
$KEY_VAULT_NAME = az keyvault list -g rg-az400-handson --query "[0].name" -o tsv
$WEBAPP_NAME = az webapp list -g rg-az400-handson --query "[0].name" -o tsv

# 環境変数を追加
az webapp config appsettings set `
  --name $WEBAPP_NAME `
  --resource-group rg-az400-handson `
  --settings KEY_VAULT_URL="https://$KEY_VAULT_NAME.vault.azure.net/"

Write-Host "✅ KEY_VAULT_URL設定完了: https://$KEY_VAULT_NAME.vault.azure.net/"
```

**手順2.5: CLI実行ユーザーに権限を付与（シークレット設定のため）**

⚠️ **重要**: Bicepで設定される権限はWeb AppのManaged Identity用です。Azure CLIでシークレットを設定するには、**CLI実行ユーザー自身**にも権限が必要です。

```powershell
# 現在のユーザーのObject IDを取得
$CURRENT_USER_OID = az ad signed-in-user show --query id -o tsv

# Key Vault名を取得（まだ設定していない場合）
$KEY_VAULT_NAME = az keyvault list -g rg-az400-handson --query "[0].name" -o tsv

# Access Policyを追加（secrets の get, list, set 権限）
az keyvault set-policy `
  --name $KEY_VAULT_NAME `
  --object-id $CURRENT_USER_OID `
  --secret-permissions get list set

Write-Host "✅ CLI実行ユーザーに権限付与完了"
```

**AZ-400試験ポイント**:
- **Data Plane権限**: Access Policy（secrets操作） ← シークレット設定に必要
- **Management Plane権限**: IAM/RBAC（Key Vault自体の管理） ← リソース管理に必要

**手順3: 本ハンズオン用シークレットを設定**

**前提: 環境変数の設定**

まず、Key Vault名を取得して変数に設定します（手順2.5で設定済みの場合はスキップ）：

```powershell
# Key Vault名を取得
$KEY_VAULT_NAME = az keyvault list -g rg-az400-handson --query "[0].name" -o tsv

# 確認
Write-Host "Key Vault名: $KEY_VAULT_NAME"
```

**3-1. 必須シークレット（アプリケーション動作用）**

```powershell
# DatabaseConnectionString（app.jsの /secret エンドポイントで使用）
# 注: SQL Databaseは未デプロイですが、動作確認用に設定
az keyvault secret set `
  --vault-name $KEY_VAULT_NAME `
  --name DatabaseConnectionString `
  --value "Server=tcp:demo.database.windows.net,1433;Database=demoDb;Authentication=Active Directory Default;Encrypt=true;"

Write-Host "✅ DatabaseConnectionString設定完了（デモ用）"
```

**3-2. 推奨シークレット（学習目的）**

```powershell
# APIキー（外部API連携の例）
az keyvault secret set `
  --vault-name $KEY_VAULT_NAME `
  --name ApiKey `
  --value "demo-api-key-12345-for-learning"

# アプリケーションシークレット（認証の例）
az keyvault secret set `
  --vault-name $KEY_VAULT_NAME `
  --name AppSecret `
  --value "demo-app-secret-67890"

Write-Host "✅ 学習用シークレット設定完了"
```

**3-3. セキュア入力の練習（AZ-400重要スキル）**

⚠️ **注意**: 以下のコード全体を一度に実行してください（1行ずつ実行すると変数が失われます）

```powershell
# パスワード非表示入力（入力は画面に表示されない）
$SecureInput = Read-Host "パスワードを入力（入力は表示されません）" -AsSecureString

# SecureString → プレーンテキストに変換（Azure CLIで使用するため）
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureInput)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

# Key Vaultに保存
az keyvault secret set `
  --vault-name $KEY_VAULT_NAME `
  --name SecurePassword `
  --value $PlainPassword

# メモリから削除（セキュリティのため）
$PlainPassword = $null
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

Write-Host "✅ セキュアパスワード設定完了"
```

**別の方法: 1行で実行**

```powershell
# プロンプトなしで直接値を指定（学習目的）
az keyvault secret set `
  --vault-name $KEY_VAULT_NAME `
  --name SecurePassword `
  --value "MySecureP@ssw0rd123!"
```

**手順4: 設定確認とアプリケーションテスト**

**4-1. シークレット確認（値は表示しない）**

```powershell
# シークレット一覧（値は表示されない）
az keyvault secret list --vault-name $KEY_VAULT_NAME --output table

# 特定シークレットの存在確認（値は表示しない）
az keyvault secret show `
  --vault-name $KEY_VAULT_NAME `
  --name ApiKey `
  --query "name" -o tsv

# ⚠️ 値を確認する場合（本番環境では慎重に）
az keyvault secret show `
  --vault-name $KEY_VAULT_NAME `
  --name ApiKey `
  --query "value" -o tsv
```

**AZ-400試験ポイント**:

| シナリオ | 正しい方法 | 誤った方法 |
|---------|-----------|----------|
| Bicepでのシークレット管理 | デプロイ後にCLI設定 | ❌ Bicepにハードコード |
| GitHub Actionsからの設定 | GitHub Secrets → 環境変数 → az CLI | ❌ YAMLにパスワード記述 |
| ローカル開発環境 | .env（.gitignore済） → CLI設定 | ❌ コミット可能なファイルに保存 |
| CI/CDパイプライン | Variable Groups（暗号化） | ❌ パイプライン定義にプレーンテキスト |
| **Bicep循環依存** | **リソース分割・段階的デプロイ** | **❌ 相互参照** |

**🔧 Bicep循環依存の解決パターン（頻出）**:

```bicep
// ❌ NG: 循環依存が発生
module webApp 'webapp.bicep' = {
  params: { keyVaultUrl: keyVault.outputs.uri }
}
module keyVault 'keyvault.bicep' = {
  params: { identityId: webApp.outputs.identityId }  // 循環！
}

// ✅ OK: 段階的デプロイで解決
module webApp 'webapp.bicep' = { ... }
module keyVault 'keyvault.bicep' = {
  params: { identityId: webApp.outputs.identityId }  // 一方向
}
resource appSettings 'Microsoft.Web/sites/config@2023-01-01' = {
  name: 'myapp-dev-webapp/appsettings'  // パラメータから直接構築
  properties: { KEY_VAULT_URL: keyVault.outputs.uri }
}
```

```bash
# 期待される出力:
# Name                          Enabled
# ----------------------------  ---------
# DatabaseConnectionString      True
# ApiKey                        True
# AppSecret                     True
# SecurePassword                True

# 特定シークレットの存在確認（値は表示しない）
az keyvault secret show `
  --vault-name $KEY_VAULT_NAME `
  --name DatabaseConnectionString `
  --query "name" -o tsv

# ⚠️ 値を確認する場合（本番環境では慎重に）
az keyvault secret show `
  --vault-name $KEY_VAULT_NAME `
  --name ApiKey `
  --query "value" -o tsv
```

**4-2. Web Appを起動**

⚠️ **重要**: デプロイ直後やリソース作成後、Web Appが停止状態になっている場合があります。

```powershell
# Web App名を取得（まだ設定していない場合）
$WEBAPP_NAME = az webapp list -g rg-az400-handson --query "[0].name" -o tsv

# Web Appの状態を確認
az webapp show `
  --name $WEBAPP_NAME `
  --resource-group rg-az400-handson `
  --query state -o tsv

# Web Appを起動
az webapp start `
  --name $WEBAPP_NAME `
  --resource-group rg-az400-handson

Write-Host "✅ Web App起動完了: $WEBAPP_NAME"

# 起動確認（数秒待つ）
Start-Sleep -Seconds 10
az webapp show `
  --name $WEBAPP_NAME `
  --resource-group rg-az400-handson `
  --query state -o tsv
# 期待される出力: Running
```

**⚠️ 重要な注意事項**

この時点（Day 2）では、**Azure インフラのみ**デプロイされており、**アプリケーションコードはまだデプロイされていません**。

- ✅ **デプロイ済み**: Web App、Key Vault、Application Insights（インフラ）
- ❌ **未デプロイ**: Node.js アプリケーション（`src/webapp/app.js`）
- 📅 **Day 3で実施**: CI/CDパイプラインによるアプリケーションデプロイ

そのため、**現時点でWebアプリにアクセスすると404エラーが返ります**（正常な動作）。

**4-3. Web Appの状態確認（現時点での確認）**

```powershell
# Web App URLを取得
$WEBAPP_URL = az webapp show `
  --name $WEBAPP_NAME `
  --resource-group rg-az400-handson `
  --query defaultHostName -o tsv

# アクセス確認（404が返るのが正常）
Invoke-RestMethod -Uri "https://$WEBAPP_URL/health"
# 期待される結果: 404 Not Found（アプリ未デプロイのため）

Write-Host "ℹ️  404エラーが出るのは正常です（アプリケーション未デプロイ）"
Write-Host "ℹ️  Day 3でCI/CDパイプラインを使ってデプロイします"
```

**4-4. 環境変数とManaged Identity設定の確認（重要）**

アプリケーションはまだデプロイされていませんが、**インフラの設定が正しいか**を確認しましょう：

```powershell
# 1. KEY_VAULT_URL環境変数の確認
Write-Host "=== KEY_VAULT_URL環境変数 ==="
az webapp config appsettings list `
  --name $WEBAPP_NAME `
  --resource-group rg-az400-handson `
  --query "[?name=='KEY_VAULT_URL'].{Name:name, Value:value}" -o table
# 期待: KEY_VAULT_URL   https://az400-dev-kv-xxxxx.vault.azure.net/

# 2. Managed Identityの有効化確認
Write-Host "`n=== Managed Identity ==="
az webapp identity show `
  --name $WEBAPP_NAME `
  --resource-group rg-az400-handson `
  --query "{Type:type, PrincipalId:principalId}" -o table
# 期待: Type=SystemAssigned, PrincipalId=（GUID）

# 3. Key VaultのAccess Policies確認
Write-Host "`n=== Key Vault Access Policies ==="
$WEBAPP_PRINCIPAL_ID = az webapp identity show `
  --name $WEBAPP_NAME `
  --resource-group rg-az400-handson `
  --query principalId -o tsv

az keyvault show `
  --name $KEY_VAULT_NAME `
  --query "properties.accessPolicies[?objectId=='$WEBAPP_PRINCIPAL_ID'].permissions.secrets" -o json
# 期待: ["get","list"]

Write-Host "`n✅ Day 2のインフラ設定は完了しています"
Write-Host "📅 Day 3でアプリケーションをデプロイすると、/secretエンドポイントが動作します"
```

**【オプション】今すぐテストしたい場合の手動デプロイ**

Day 3を待たずに動作確認したい場合は、以下の手動デプロイを実行できます：

```powershell
# Azure Container Registryを作成（まだない場合）
$ACR_NAME = "az400acr$(Get-Random -Minimum 1000 -Maximum 9999)"
az acr create `
  --name $ACR_NAME `
  --resource-group rg-az400-handson `
  --sku Basic `
  --admin-enabled true

# Dockerイメージをビルド＆プッシュ
az acr build `
  --registry $ACR_NAME `
  --image webapp:latest `
  --file src/webapp/Dockerfile `
  src/webapp

# Web AppにACR認証情報を設定
$ACR_LOGIN_SERVER = az acr show --name $ACR_NAME --query loginServer -o tsv
$ACR_USERNAME = az acr credential show --name $ACR_NAME --query username -o tsv
$ACR_PASSWORD = az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv

az webapp config container set `
  --name $WEBAPP_NAME `
  --resource-group rg-az400-handson `
  --docker-custom-image-name "$ACR_LOGIN_SERVER/webapp:latest" `
  --docker-registry-server-url "https://$ACR_LOGIN_SERVER" `
  --docker-registry-server-user $ACR_USERNAME `
  --docker-registry-server-password $ACR_PASSWORD

# 再起動
az webapp restart --name $WEBAPP_NAME --resource-group rg-az400-handson

Write-Host "⏳ デプロイ完了まで1-2分待機..."
Start-Sleep -Seconds 60

# 動作確認
Invoke-RestMethod -Uri "https://$WEBAPP_URL/health"

# 期待される出力:
# 動作確認
Invoke-RestMethod -Uri "https://$WEBAPP_URL/health"
# 期待される出力: 
# {
#   "status": "healthy",
#   "timestamp": "2024-01-01T12:00:00.000Z"
# }

Invoke-RestMethod -Uri "https://$WEBAPP_URL/secret"
# 期待される出力:
# {
#   "secretName": "DatabaseConnectionString",
#   "retrieved": true,
#   "message": "✅ Secret retrieved from Key Vault successfully!",
#   "vaultUrl": "https://az400-dev-kv-xxxxx.vault.azure.net/"
# }
```

**4-5. トラブルシューティング（手動デプロイした場合）**

手動デプロイを実行した場合のエラー確認：

```powershell
# Web Appのログ確認
az webapp log tail `
  --name $WEBAPP_NAME `
  --resource-group rg-az400-handsonft.KeyVault/vaults/secrets@2023-07-01' = if (databaseConnectionString != '') {
  parent: keyVault
  name: 'DatabaseConnectionString'
  properties: {
    value: databaseConnectionString  // @secure()で保護
  }
}
```

```powershell
# パラメータファイルで渡す場合（.gitignore必須）
az deployment group create `
  --parameters databaseConnectionString="$DB_CONNECTION_STRING"
```

**Git管理のベストプラクティス**:

```powershell
# .gitignoreに追加（必須）
@"
# シークレット関連ファイル（絶対コミット禁止）
*.secrets.json
*.secrets.*.json
.env
.env.local
**/appsettings.Development.json
"@ | Out-File -FilePath .gitignore -Append -Encoding utf8

# 既にコミット済みのシークレットを削除
git rm --cached infra/bicep/parameters/*.secrets.json
git commit -m "Remove secrets from git history"

# git-secretsツールでシークレット検出（推奨）
git secrets --install
git secrets --register-aws  # AWSキー検出
git secrets --add 'password|secret|key'
```

#### 1.5 セキュアスクリプトとCI/CDによる自動化（実践）

**🎯 学習目標**:
- セキュアなスクリプトによる自動化
- GitHub Actionsでのシークレット管理
- ローカル開発と本番環境のベストプラクティス

---

##### 方法1: セキュアBashスクリプト（ローカル開発用）

**scripts/setup/set-keyvault-secrets.sh** を使用します。

**セットアップ（Windows）**:

```powershell
# 1. Git Bashのインストール確認
git --version

# 2. スクリプトに実行権限を付与
.\scripts\setup\setup.ps1

# または手動で
bash -c "chmod +x scripts/setup/set-keyvault-secrets.sh"
```

**実行手順**:

```powershell
# 1. Azure CLIでログイン
az login

# 2. リソースグループを環境変数に設定
$env:RESOURCE_GROUP = "rg-az400-handson"

# 3. スクリプトを実行（Git Bash経由）
bash scripts/setup/set-keyvault-secrets.sh

# ⚠️ エラーが出た場合: "$'\r': command not found"
# → 改行コードをLFに変換
bash -c "sed -i 's/\r$//' scripts/setup/set-keyvault-secrets.sh"
bash -c "chmod +x scripts/setup/set-keyvault-secrets.sh"
# → 再度実行
bash scripts/setup/set-keyvault-secrets.sh
```

**実行時の対話フロー**:

```
🔐 Azure Key Vault シークレット設定スクリプト
================================================

📋 Key Vault検出中...
✅ Key Vault見つかりました: az400-dev-kv

🔧 SQL Server情報を取得中...
✅ SQL Server FQDN: az400-dev-sqlserver.database.windows.net

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
シークレット入力
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SQL管理者パスワードを入力: ************  ← 入力内容は非表示
API Keyを入力 (スキップ可): ************

✅ DatabaseConnectionString を設定しました
✅ ApiKey を設定しました

🔍 設定されたシークレット一覧（値は表示されません）:
  - DatabaseConnectionString
  - ApiKey

✅ すべてのシークレット設定が完了しました！
```

**セキュリティ機能**:

| 機能 | 実装 | 効果 |
|------|------|------|
| 履歴無効化 | `set +o history` | `.bash_history`に記録されない |
| パスワード非表示 | `read -sp` | 入力時に画面に表示されない |
| メモリクリア | `trap cleanup EXIT` | スクリプト終了時に変数削除 |
| デバッグ無効 | `set +x` | パスワードがログに出力されない |
| エラー処理 | カスタムハンドラー | エラーメッセージにシークレット含まない |
| 出力抑制 | `--output none` | Azure CLIの出力にシークレット含まない |

**詳細ドキュメント**: [scripts/setup/README.md](../../scripts/setup/README.md)

---

##### 方法2: GitHub Actions（本番環境推奨）

**事前準備: GitHub Secretsの設定**

詳細ガイド: [.github/GITHUB_SECRETS_SETUP.md](../../.github/GITHUB_SECRETS_SETUP.md)

---

#### ステップ 1-1: Azure認証の準備（サービスプリンシパル作成）

GitHub ActionsからAzureに接続するための認証情報を作成します。方法は2つあります：

| 方法 | セキュリティ | 設定の複雑さ | 本ハンズオンでの使用 |
|------|------------|------------|-------------------|
| **方法A: 従来の方法（--sdk-auth）** | パスワードベース | 簡単 | ✅ 本ハンズオンで使用 |
| **方法B: Federated Credential（推奨）** | パスワードレス | やや複雑 | 参考情報として記載 |

**このハンズオンでは方法Aを使用します。**

---

##### 方法A: 従来の方法（--sdk-auth）⭐ 本ハンズオンで使用

**Azure認証情報の作成手順**:

**🔒 セキュリティ重要**: JSONファイルをリポジトリに作成せず、安全な方法で設定します。

```powershell
# 1. サブスクリプションIDを取得
$SUBSCRIPTION_ID = az account show --query id -o tsv

# 2. サービスプリンシパルを作成してクリップボードにコピー（推奨）
az ad sp create-for-rbac `
  --name "github-actions-az400" `
  --role contributor `
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-az400-handson" `
  --sdk-auth | Set-Clipboard

Write-Host "✅ Azure認証情報をクリップボードにコピーしました" -ForegroundColor Green
Write-Host "⚠️ この情報は機密です。GitHub Secretsに設定したら、クリップボードをクリアしてください" -ForegroundColor Yellow

# 3. クリップボードから直接GitHub Secretsに設定（次のステップで使用）
```

**🔒 セキュリティベストプラクティス**:

✅ **推奨**: クリップボード経由で直接設定（ファイル不要）  
⚠️ **非推奨**: リポジトリ内にJSONファイルを作成  
🚫 **絶対NG**: JSONファイルをGitにコミット

<details>
<summary>📖 万が一ファイルを作成した場合の対処法（クリックして展開）</summary>

```powershell
# .gitignoreに追加されているか確認
Get-Content .gitignore | Select-String "azure-credentials.json"

# 追加されていない場合は手動で追加
Add-Content .gitignore "`nazure-credentials.json"

# 既にコミットしてしまった場合はGit履歴から削除
git rm --cached azure-credentials.json
git commit -m "Remove sensitive credentials file"

# ファイルを完全に削除
Remove-Item azure-credentials.json -Force

# サービスプリンシパルを再作成（漏洩した場合）
az ad sp delete --id <clientId>
# その後、新しいサービスプリンシパルを作成
```

</details>

**出力例**:
```json
{
  "clientId": "xxxx",
  "clientSecret": "xxxx",
  "subscriptionId": "xxxx",
  "tenantId": "xxxx",
  ...
}
```

---

#### ステップ 1-2: GitHub Secretsの設定

**クリップボードにコピーした認証情報**とその他の設定値を、以下の**いずれかの方法**でGitHub Secretsに設定します。

**必要なGitHub Secrets一覧**:

| シークレット名 | 説明 | 取得方法 |
|-------------|------|---------|
| `AZURE_CREDENTIALS` | Azure認証情報（JSON） | 上記で作成した `azure-credentials.json` の内容 |
| `SQL_SERVER_FQDN` | SQL Server FQDN | `az sql server show --query fullyQualifiedDomainName` |
| `SQL_DATABASE_NAME` | データベース名 | 例: `az400db` |
| `SQL_ADMIN_USER` | SQL管理者名 | 例: `sqladmin` |
| `SQL_ADMIN_PASSWORD` | SQL管理者パスワード | デプロイ時に設定した値 |
| `API_KEY` | 外部APIキー（学習用） | デモ値: `demo-api-key-12345-for-learning` |

---

##### 設定方法①: Web UIで手動設定

1. GitHubリポジトリ → **Settings** → **Secrets and variables** → **Actions**
2. **"New repository secret"** をクリック
3. Name と Secret を入力して保存

**手順**:
- `AZURE_CREDENTIALS`: **クリップボードにコピーした認証情報**をペースト（Ctrl+V）
- `SQL_SERVER_FQDN`: 値を入力
- `SQL_DATABASE_NAME`: 値を入力
- `SQL_ADMIN_USER`: 値を入力
- `SQL_ADMIN_PASSWORD`: 値を入力
- `API_KEY`: 学習用デモ値を入力 → `demo-api-key-12345-for-learning`

**完了後**: セキュリティのためクリップボードをクリアしてください。

---

##### 設定方法②: GitHub CLIでコマンド設定

**🔒 セキュリティ重要**: クリップボードから直接設定します。

```powershell
# GitHub CLIインストール確認
gh --version

# ログイン
gh auth login

# ステップ1でクリップボードにコピーした認証情報を設定
# クリップボードから直接設定（ファイル作成不要）
Get-Clipboard | gh secret set AZURE_CREDENTIALS

# その他のシークレットを設定
gh secret set SQL_SERVER_FQDN -b "az400-dev-sqlserver.database.windows.net"
gh secret set SQL_DATABASE_NAME -b "az400db"
gh secret set SQL_ADMIN_USER -b "sqladmin"
gh secret set SQL_ADMIN_PASSWORD -b "YourSecurePassword123!"
gh secret set API_KEY -b "demo-api-key-12345-for-learning"

# クリップボードをクリア（セキュリティ対策）
Set-Clipboard -Value ""

# 確認
gh secret list
```

---

##### 設定方法③: 対話的スクリプトで一括設定（推奨）🌟

```powershell
# setup-github-secrets.ps1
# GitHub Secretsを対話的に設定するスクリプト
# 
# 用途: AZ-400ハンズオン用のGitHub Secretsを安全に設定
# セキュリティ: クリップボード経由でファイルを作成せず、機密情報を扱う

# ========================================
# 1. 前提条件チェック
# ========================================

# GitHub CLIがインストールされているか確認
# GitHub CLIは'gh'コマンドでGitHub操作を行うツール
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "❌ GitHub CLI がインストールされていません" -ForegroundColor Red
    Write-Host "https://cli.github.com/ からインストールしてください"
    exit 1
}

# ========================================
# 2. GitHub認証確認
# ========================================

# ログイン確認
# GitHub CLIが認証されているかチェック
gh auth status
if ($LASTEXITCODE -ne 0) {
    Write-Host "GitHub CLIでログインしてください"
    gh auth login
}

Write-Host "🔐 GitHub Secrets を設定します" -ForegroundColor Green
Write-Host ""

# ========================================
# 3. Azure認証情報の設定
# ========================================

# AZURE_CREDENTIALS: Azureサービスプリンシパル認証情報（JSON形式）
# - GitHub ActionsからAzureにログインするために必要
# - セキュリティ: ファイルではなくクリップボードから直接設定
# - 前提: 事前に`az ad sp create-for-rbac --sdk-auth | Set-Clipboard`を実行済み
Write-Host "📋 ステップ1でクリップボードにコピーした Azure認証情報を使用します" -ForegroundColor Cyan
$useClipboard = Read-Host "クリップボードから設定しますか？ (y/n, Enter でスキップ)"
if ($useClipboard -eq 'y') {
    # クリップボードの内容をそのままGitHub Secretに設定
    Get-Clipboard | gh secret set AZURE_CREDENTIALS
    Write-Host "✅ AZURE_CREDENTIALS を設定しました" -ForegroundColor Green
    
    # セキュリティのためクリップボードをクリア
    # 機密情報がクリップボードに残らないようにする
    Set-Clipboard -Value ""
    Write-Host "🔒 クリップボードをクリアしました" -ForegroundColor Green
}

# ========================================
# 4. SQL Server接続情報の設定
# ========================================

# SQL_SERVER_FQDN: SQL Serverの完全修飾ドメイン名
# - 形式: <server-name>.database.windows.net
# - 取得方法: az sql server show --query fullyQualifiedDomainName
Write-Host ""
Write-Host "💾 SQL Server接続情報を設定します" -ForegroundColor Cyan
$sqlServerFqdn = Read-Host "SQL Server FQDN (Enter でスキップ)"
if ($sqlServerFqdn) {
    gh secret set SQL_SERVER_FQDN -b $sqlServerFqdn
    Write-Host "✅ SQL_SERVER_FQDN を設定しました" -ForegroundColor Green
}

# SQL_DATABASE_NAME: データベース名
# - 例: az400db, handson-database など
$sqlDbName = Read-Host "SQL Database名 (Enter でスキップ)"
if ($sqlDbName) {
    gh secret set SQL_DATABASE_NAME -b $sqlDbName
    Write-Host "✅ SQL_DATABASE_NAME を設定しました" -ForegroundColor Green
}

# SQL_ADMIN_USER: SQL Server管理者のユーザー名
# - Bicepデプロイ時に設定した管理者名
# - 例: sqladmin, azureuser など
$sqlAdminUser = Read-Host "SQL管理者ユーザー名 (Enter でスキップ)"
if ($sqlAdminUser) {
    gh secret set SQL_ADMIN_USER -b $sqlAdminUser
    Write-Host "✅ SQL_ADMIN_USER を設定しました" -ForegroundColor Green
}

# ========================================
# 5. 機密情報の設定（SecureString使用）
# ========================================

# SQL_ADMIN_PASSWORD: SQL Server管理者のパスワード
# - セキュリティ: SecureStringで入力（画面にマスク表示）
# - コマンド履歴にも残らない
Write-Host ""
Write-Host "🔑 機密情報を設定します（入力は画面に表示されません）" -ForegroundColor Cyan
$sqlAdminPassword = Read-Host "SQL管理者パスワード (Enter でスキップ)" -AsSecureString
if ($sqlAdminPassword.Length -gt 0) {
    # SecureStringを平文に変換（メモリ上でのみ）
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlAdminPassword)
    )
    # GitHub Secretに設定
    gh secret set SQL_ADMIN_PASSWORD -b $plainPassword
    Write-Host "✅ SQL_ADMIN_PASSWORD を設定しました" -ForegroundColor Green
    
    # 変数をクリア（メモリから削除）
    $plainPassword = $null
}

# API_KEY: 外部APIキー（学習用）
# - このハンズオンでは学習目的のデモ値を使用
# - デモ値: demo-api-key-12345-for-learning
# - セキュリティ: SecureStringで入力（実際のAPIキーと同じ扱い）
Write-Host "学習用デモ値を設定する場合: demo-api-key-12345-for-learning" -ForegroundColor Yellow
$apiKey = Read-Host "API Key (Enter でスキップ)" -AsSecureString
if ($apiKey.Length -gt 0) {
    # SecureStringを平文に変換（メモリ上でのみ）
    $plainApiKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($apiKey)
    )
    # GitHub Secretに設定
    gh secret set API_KEY -b $plainApiKey
    Write-Host "✅ API_KEY を設定しました" -ForegroundColor Green
    
    # 変数をクリア（メモリから削除）
    $plainApiKey = $null
}

# ========================================
# 6. 設定確認
# ========================================

Write-Host ""
Write-Host "🔍 設定されたシークレット一覧:" -ForegroundColor Cyan
# GitHub Secretsのリストを表示（値は表示されず、名前と更新日時のみ）
gh secret list

# ========================================
# 7. 完了メッセージ
# ========================================

Write-Host ""
Write-Host "✅ GitHub Secrets の設定が完了しました！" -ForegroundColor Green
Write-Host ""
Write-Host "📌 次のステップ:" -ForegroundColor Yellow
Write-Host "  1. GitHub ActionsでWorkflowを実行してください" -ForegroundColor White
Write-Host "  2. リポジトリのActions タブから 'Deploy Secrets to Key Vault' を選択" -ForegroundColor White
Write-Host "  3. 'Run workflow' をクリックして環境（dev/staging/prod）を選択" -ForegroundColor White
```

**スクリプト実行方法**:

```powershell
# 前提: ステップ1でAzure認証情報をクリップボードにコピー済み

# スクリプトを実行
cd scripts/setup
.\setup-github-secrets.ps1

# プロンプトで以下を入力：
# ✅ Azure認証情報: y （クリップボードから設定）
# ✅ SQL Server FQDN: az400-dev-sqlserver.database.windows.net
# ✅ SQL Database名: az400db
# ✅ SQL管理者ユーザー名: sqladmin
# ✅ SQL管理者パスワード: （SecureStringで非表示入力）
# ✅ API Key: demo-api-key-12345-for-learning （学習用デモ値）
```

**実行例**:
```
🔐 GitHub Secrets を設定します

📋 ステップ1でクリップボードにコピーした Azure認証情報を使用します
クリップボードから設定しますか？ (y/n, Enter でスキップ): y
✅ AZURE_CREDENTIALS を設定しました
🔒 クリップボードをクリアしました

💾 SQL Server接続情報を設定します
SQL Server FQDN (Enter でスキップ): az400-dev-sqlserver.database.windows.net
✅ SQL_SERVER_FQDN を設定しました
SQL Database名 (Enter でスキップ): az400db
✅ SQL_DATABASE_NAME を設定しました
SQL管理者ユーザー名 (Enter でスキップ): sqladmin
✅ SQL_ADMIN_USER を設定しました

🔑 機密情報を設定します（入力は画面に表示されません）
SQL管理者パスワード (Enter でスキップ): **********
✅ SQL_ADMIN_PASSWORD を設定しました
学習用デモ値を設定する場合: demo-api-key-12345-for-learning
API Key (Enter でスキップ): **********
✅ API_KEY を設定しました

🔍 設定されたシークレット一覧:
AZURE_CREDENTIALS    Updated 2026-05-08
SQL_SERVER_FQDN      Updated 2026-05-08
SQL_DATABASE_NAME    Updated 2026-05-08
SQL_ADMIN_USER       Updated 2026-05-08
SQL_ADMIN_PASSWORD   Updated 2026-05-08
API_KEY              Updated 2026-05-08

✅ GitHub Secrets の設定が完了しました！

📌 次のステップ: → 下記の **ステップ 1-3** に進んでGitHub ActionsでKey Vaultにデプロイしてください
```

**スクリプトの場所**: [scripts/setup/setup-github-secrets.ps1](../../scripts/setup/setup-github-secrets.ps1)

詳細ガイド: [.github/GITHUB_SECRETS_SETUP.md](../../.github/GITHUB_SECRETS_SETUP.md)

---

##### 方法B: Federated Credential（参考情報）🔐

**より安全なパスワードレス認証**。本番環境やセキュリティ重視のプロジェクトで推奨されますが、設定がやや複雑です。

<details>
<summary>📖 Federated Credentialの設定手順（クリックして展開）</summary>

#### ステップ1: サービスプリンシパル作成

```powershell
# サブスクリプションIDを取得
$SUBSCRIPTION_ID = az account show --query id -o tsv

# サービスプリンシパル作成（シークレットなし）
$SP_OUTPUT = az ad sp create-for-rbac `
  --name "github-actions-az400-federated" `
  --role contributor `
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-az400-handson" `
  --json-auth | ConvertFrom-Json

# 重要な値を保存
$CLIENT_ID = $SP_OUTPUT.clientId
$TENANT_ID = $SP_OUTPUT.tenantId

Write-Host "Client ID: $CLIENT_ID"
Write-Host "Tenant ID: $TENANT_ID"
Write-Host "Subscription ID: $SUBSCRIPTION_ID"
```

#### ステップ2: Federated Credentialの設定

```powershell
# GitHubリポジトリ情報を設定
$GITHUB_ORG = "your-github-org"  # GitHubのOrg名またはユーザー名
$GITHUB_REPO = "az400-handson-bootcamp"  # リポジトリ名

# Federated Credentialを作成（mainブランチ用）
az ad app federated-credential create `
  --id $CLIENT_ID `
  --parameters @"
{
  \"name\": \"github-federated-main\",
  \"issuer\": \"https://token.actions.githubusercontent.com\",
  \"subject\": \"repo:$GITHUB_ORG/${GITHUB_REPO}:ref:refs/heads/main\",
  \"audiences\": [\"api://AzureADTokenExchange\"]
}
"@
```

#### ステップ3: GitHub Secretsの設定

**必要なSecrets（AZURE_CREDENTIALSは不要）**:

```powershell
gh secret set AZURE_CLIENT_ID -b $CLIENT_ID
gh secret set AZURE_TENANT_ID -b $TENANT_ID
gh secret set AZURE_SUBSCRIPTION_ID -b $SUBSCRIPTION_ID

# その他のSecrets（SQL, API Keyなど）は方法Aと同じ
gh secret set SQL_SERVER_FQDN -b "az400-dev-sqlserver.database.windows.net"
gh secret set SQL_DATABASE_NAME -b "az400db"
gh secret set SQL_ADMIN_USER -b "sqladmin"
gh secret set SQL_ADMIN_PASSWORD -b "YourSecurePassword123!"
```

#### ステップ4: GitHub Actionsワークフローの修正（OIDC認証用）

> **注**: 方法A（AZURE_CREDENTIALS使用）のワークフロー詳細は、**ステップ3**をご覧ください。  
> ここでは、方法B（Federated Credential）特有のOIDC認証設定を説明します。

```yaml
# .github/workflows/deploy.yml
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write  # OIDC認証に必要（方法B特有）
      contents: read
    steps:
      - name: Azure Login (OIDC)
        uses: azure/login@v1
        with:
          # 方法Bではcreds不要、代わりにOIDCトークンを使用
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

**方法Aとの違い**:
- ❌ `creds: ${{ secrets.AZURE_CREDENTIALS }}` は不要（パスワードレス）
- ✅ `permissions: id-token: write` が必要（OIDCトークン発行）
- ✅ client-id, tenant-id, subscription-id を個別に指定

**メリット**:
- ✅ シークレット（パスワード）が不要
- ✅ 定期的なローテーション不要
- ✅ 高いセキュリティ

**デメリット**:
- ⚠️ 設定手順がやや複雑
- ⚠️ 既存ワークフローの修正が必要

詳細: [GitHub公式ドキュメント](https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)

</details>

**このハンズオンでは方法Aを使用しますが、実務では方法Bの採用を検討してください。**

---

##### ✅ GitHub Secrets設定完了の確認

設定が完了したら、以下の方法で確認します：

**GitHub Web UIで確認**:
1. リポジトリ → Settings → Secrets and variables → Actions
2. 以下のSecretsが表示されていることを確認：
   - AZURE_CREDENTIALS
   - SQL_SERVER_FQDN
   - SQL_DATABASE_NAME
   - SQL_ADMIN_USER
   - SQL_ADMIN_PASSWORD
   - API_KEY（オプション）

**GitHub CLIで確認**:
```powershell
gh secret list
```

**出力例**:
```
AZURE_CREDENTIALS    Updated 2026-05-05
SQL_SERVER_FQDN      Updated 2026-05-05
SQL_DATABASE_NAME    Updated 2026-05-05
SQL_ADMIN_USER       Updated 2026-05-05
SQL_ADMIN_PASSWORD   Updated 2026-05-05
```

---

#### ステップ 1-3: GitHub ActionsでKey Vaultにシークレットをデプロイ

GitHub Secretsの設定が完了したら、GitHub Actionsワークフローを使用してKey Vaultにシークレットをデプロイします。

##### 🔧 ワークフロー実行手順

1. **GitHubリポジトリページに移動**
2. **Actionsタブをクリック**
3. **"Deploy Secrets to Key Vault"** ワークフローを選択
4. **"Run workflow"** をクリック
5. **環境を選択** (dev/staging/prod)
6. **"Run workflow"** を実行

---

##### 📄 ワークフロー定義の詳細

ワークフローファイル: [.github/workflows/deploy-secrets.yml](../../.github/workflows/deploy-secrets.yml)

**主要な処理内容**:

```yaml
name: Deploy Secrets to Key Vault

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment (dev/staging/prod)'
        required: true
        default: 'dev'
        type: choice
        options:
          - dev
          - staging
          - prod

jobs:
  deploy-secrets:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    # Azure認証（方法A: AZURE_CREDENTIALS使用）
    - name: Azure Login
      uses: azure/login@v3
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}
    
    # Key Vault名を動的取得
    - name: Get Key Vault Name
      id: get-kv
      run: |
        KEY_VAULT_NAME=$(az deployment group show \
          --resource-group rg-az400-handson \
          --name main \
          --query properties.outputs.keyVaultName.value -o tsv)
        echo "keyvault_name=$KEY_VAULT_NAME" >> $GITHUB_OUTPUT
    
    # データベース接続文字列を設定
    - name: Set Database Connection String
      env:
        DB_PASSWORD: ${{ secrets.SQL_ADMIN_PASSWORD }}
        SQL_SERVER_FQDN: ${{ secrets.SQL_SERVER_FQDN }}
        SQL_DATABASE_NAME: ${{ secrets.SQL_DATABASE_NAME }}
        SQL_ADMIN_USER: ${{ secrets.SQL_ADMIN_USER }}
      run: |
        CONNECTION_STRING="Server=tcp:${SQL_SERVER_FQDN},1433;Database=${SQL_DATABASE_NAME};User ID=${SQL_ADMIN_USER};Password=${DB_PASSWORD};Encrypt=true;"
        
        az keyvault secret set \
          --vault-name "${{ steps.get-kv.outputs.keyvault_name }}" \
          --name DatabaseConnectionString \
          --value "$CONNECTION_STRING" \
          --output none
    
    # API Keyを設定
    - name: Set API Key
      if: ${{ secrets.API_KEY != '' }}
      env:
        API_KEY: ${{ secrets.API_KEY }}
      run: |
        az keyvault secret set \
          --vault-name "${{ steps.get-kv.outputs.keyvault_name }}" \
          --name ApiKey \
          --value "$API_KEY" \
          --output none
```

**ポイント**:
- ✅ `workflow_dispatch`: 手動実行トリガー
- ✅ `secrets.AZURE_CREDENTIALS`: ステップ2で設定したAzure認証情報を使用
- ✅ 環境変数 `env:` でシークレットを安全に受け渡し
- ✅ `--output none`: 機密情報をログに出力しない

---

##### ✅ ワークフロー実行結果の確認

```
Run workflow
✅ Checkout code
✅ Azure Login
✅ Get Key Vault Name: az400-dev-kv
✅ Set Database Connection String (Managed Identity)
✅ Set API Key
✅ Verify Secrets Set
   - DatabaseConnectionString: ✅
   - ApiKey: ✅

✅ Workflow completed successfully
```

---

##### 代替方法: Azure CLIで直接Key Vaultに設定

GitHub Actionsを使わず、Azure CLIで直接Key Vaultにシークレットを設定する方法です。

<details>
<summary>📖 Azure CLI設定手順（クリックして展開）</summary>

```powershell
# Key Vault名を取得
$KEY_VAULT_NAME = az deployment group show `
  --resource-group rg-az400-handson `
  --name main `
  --query properties.outputs.keyVaultName.value -o tsv

# データベース接続文字列を自動生成
$SQL_SERVER_FQDN = az sql server show `
  --name az400-dev-sqlserver `
  --resource-group rg-az400-handson `
  --query fullyQualifiedDomainName -o tsv

DB_CONNECTION_STRING="Server=tcp:${SQL_SERVER_FQDN},1433;Database=az400db;Authentication=Active Directory Default;Encrypt=true;TrustServerCertificate=false;"

# シークレット設定
az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name DatabaseConnectionString \
  --value "$DB_CONNECTION_STRING" \
  --output none

# API Key設定（対話的・学習用デモ値）
# 学習用デモ値: demo-api-key-12345-for-learning
read -sp 'API Keyを入力: ' API_KEY
echo ""
az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name ApiKey \
  --value "$API_KEY" \
  --output none
unset API_KEY

# 確認（値は表示しない）
az keyvault secret list --vault-name $KEY_VAULT_NAME --output table
```

</details>

---

##### セキュリティベストプラクティスまとめ

**✅ やるべきこと**:

1. **ローカル開発**: セキュアスクリプト使用（`set-keyvault-secrets.sh`）
2. **CI/CD**: GitHub Actions + GitHub Secrets使用
3. **.gitignore**: `*.secrets.json`, `.env` を必ず追加
4. **Access Policies**: データプレーン権限はAccess Policiesで設定
5. **IAM**: 管理プレーン権限（Key Vault管理）はIAMで設定
6. **Managed Identity**: SQL認証には `Authentication=Active Directory Default`
7. **監査**: `git secrets` ツールでシークレット検出

**❌ やってはいけないこと**:

1. **Bicepにシークレットをハードコード**: `value: 'my-password'`
2. **YAMLにパスワード記述**: `password: 'secret123'`
3. **コミット可能なファイルにシークレット保存**: `config.json`
4. **環境変数を残したまま**: `export PASSWORD=xxx` → `unset PASSWORD` 必須
5. **デバッグ出力でシークレット表示**: `echo $PASSWORD`
6. **プレーンテキストの接続文字列**: SQL認証 → Managed Identity使用

**AZ-400試験重要ポイント**:

| シナリオ | 正解 | 不正解 |
|---------|------|--------|
| Bicepでシークレット管理 | デプロイ後にCLI設定 | Bicepにハードコード |
| GitHub Actionsでシークレット設定 | GitHub Secrets → 環境変数 | YAMLに直書き |
| 複数環境のシークレット管理 | GitHub Environments使用 | 1つのシークレットを共有 |
| SQL接続認証 | Managed Identity | ユーザー名/パスワード |
| Key Vaultシークレット読み取り | Access Policies | IAM（間違い） |
| Key Vault削除権限 | IAM | Access Policies（間違い） |

---

### ステップ 2: Managed Identity実装（90分）

#### 2.1 system-assigned vs user-assigned 理解

**system-assigned（システム割り当て）**:
- リソースと1対1の関係
- リソース作成時に自動生成
- リソース削除時に自動削除
- **使用ケース**: 単一リソースのみがアクセス必要

**user-assigned（ユーザー割り当て）**:
- 複数リソースで共有可能
- 独立したリソースとして管理
- リソース削除後も残る
- **使用ケース**: 複数VM/Web Appで同じKey Vaultアクセス

**試験ひっかけポイント**:
- Q: "複数のVMで同じKey Vaultにアクセス"
- A: **user-assigned Managed Identity** を使用

---

#### 2.1.5 Key Vault 権限モデル: Access Policies vs Azure RBAC 🔒

**Microsoft Defender for Cloud** が推奨する権限モデルの違いを理解します。

##### 📊 比較表（AZ-400 頻出）

| 項目 | Access Policies（レガシー） | Azure RBAC（✅ 推奨） |
|------|---------------------------|---------------------|
| **有効化方法** | `enableRbacAuthorization: false` | `enableRbacAuthorization: true` |
| **権限設定場所** | `accessPolicies` プロパティ | Azure RBAC ロール |
| **適用範囲** | Key Vault内のデータのみ | Key Vault全体 + データ |
| **権限粒度** | 粗い（get/list/set等） | 細かい（条件付きも可） |
| **Azure ADグループ統合** | 手動管理 | ネイティブ統合 ✅ |
| **条件付きアクセス** | 不可 | 可能 ✅ |
| **Microsoft推奨** | ❌ レガシー | ✅ **最新推奨** |
| **Defender アラート** | ⚠️ 警告が出る | ✅ 推奨に準拠 |

##### 🎯 本ハンズオンの実装方式

**Azure RBAC方式を採用** - Microsoft Defender for Cloud のセキュリティ推奨に準拠

```bicep
// infra/bicep/modules/keyvault.bicep
enableRbacAuthorization: true   // ✅ Azure RBAC使用

// データプレーン権限: Key Vault Secrets User（読み取り専用）
var keyVaultSecretsUserRole = '4633458b-17de-408a-b874-0445c86b69e6'

// 管理プレーン権限: Key Vault Administrator（管理者）
var keyVaultAdministratorRole = '00482a5a-887f-4fb3-b363-3b7fe8e74483'
```

##### 📚 主要なKey Vault RBAC ロール

| ロール名 | ロールID | 権限内容 | 使用ケース |
|---------|---------|---------|----------|
| **Key Vault Administrator** | `00482a5a-...` | すべての操作 | 管理者用 |
| **Key Vault Secrets User** | `4633458b-...` | シークレット読み取り | アプリケーション用 ✅ |
| **Key Vault Secrets Officer** | `b86a8fe4-...` | シークレット読み書き | CI/CD用 |
| **Key Vault Reader** | `21090545-...` | メタデータのみ | 監査用 |

##### 🔍 試験ひっかけポイント

**Q**: "Web AppがKey Vaultのシークレットを読むだけなら？"  
**A**: `Key Vault Secrets User` ロール（最小権限の原則）

**Q**: "GitHub ActionsでシークレットをKey Vaultに書き込むなら？"  
**A**: `Key Vault Secrets Officer` ロール

**Q**: "Access Policies と Azure RBAC は併用できる？"  
**A**: ❌ できない。`enableRbacAuthorization: true` の場合、Access Policiesは無視される

##### 🛡️ セキュリティベストプラクティス

1. ✅ **Azure RBAC方式を使用** - Microsoft推奨
2. ✅ **最小権限の原則** - 必要最低限のロールを付与
3. ✅ **Managed Identity使用** - パスワード不要
4. ✅ **定期的な権限レビュー** - 不要な権限を削除

---

#### 2.2 Bicepモジュール定義: Web App (system-assigned)

**目的**: Web Appにsystem-assigned Managed Identityを有効化するBicepモジュールを定義します。

> ⚠️ **注意**: このセクションではファイルを**作成/更新**します。デプロイは **2.4** で実行します。

**infra/bicep/modules/webapp.bicep**:

```bicep
@description('Web App名')
param webAppName string

@description('App Service Plan ID')
param appServicePlanId string

@description('ロケーション')
param location string = resourceGroup().location

@description('Key Vault URI')
param keyVaultUri string

resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'  // system-assigned Managed Identity有効化
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|18-lts'
      appSettings: [
        {
          name: 'KEY_VAULT_URL'
          value: keyVaultUri
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '18-lts'
        }
      ]
      ftpsState: 'Disabled'
    }
  }
}

output webAppName string = webApp.name
output managedIdentityPrincipalId string = webApp.identity.principalId
```

**ポイント**:
- `identity: { type: 'SystemAssigned' }`: Web Appにsystem-assigned Managed Identityを自動付与
- `managedIdentityPrincipalId`: Key Vaultのアクセスポリシー設定で使用（2.3で参照）
- このファイルは **2.4でデプロイ** します

---

#### 2.3 Bicepメインファイル更新

**目的**: 2.2で作成したWeb Appモジュールを呼び出すため、main.bicepを更新します。

> ⚠️ **注意**: このセクションではファイルを**更新**します。デプロイは **2.4** で実行します。

**infra/bicep/main.bicep**（更新）:

```bicep
targetScope = 'resourceGroup'

param environmentName string = 'dev'
param location string = resourceGroup().location
param resourcePrefix string = 'az400'

// 既存のStorage Account、App Service Planコード（Day 1）
// ...

// Key Vault モジュール
module keyVault 'modules/keyvault.bicep' = {
  name: 'keyVaultDeployment'
  params: {
    keyVaultName: '${resourcePrefix}-${environmentName}-kv'
    location: location
    managedIdentityObjectId: webApp.outputs.managedIdentityPrincipalId
  }
}

// Web App モジュール
module webApp 'modules/webapp.bicep' = {
  name: 'webAppDeployment'
  params: {
    webAppName: '${resourcePrefix}-${environmentName}-webapp'
    appServicePlanId: appServicePlan.id
    location: location
    keyVaultUri: keyVault.outputs.keyVaultUri
  }
}

output keyVaultName string = keyVault.outputs.keyVaultName
output webAppUrl string = 'https://${webApp.outputs.webAppName}.azurewebsites.net'
```

**ポイント**:
- `module webApp 'modules/webapp.bicep'`: 2.2で定義したモジュールを呼び出し
- `managedIdentityObjectId: webApp.outputs.managedIdentityPrincipalId`: Web AppのManaged IdentityをKey Vaultに自動登録
- モジュール間の依存関係を自動解決（Web App作成 → Managed Identity取得 → Key Vaultアクセス許可）
- **次の2.4でデプロイ** します

---

#### 2.4 Bicepデプロイ実行（2.2・2.3をAzureに適用）

**目的**: 2.2と2.3で定義したBicepファイルをAzureにデプロイし、実際のリソースを作成します。

**デプロイ内容**:
- ✅ Web App (system-assigned Managed Identity有効化)
- ✅ Key Vaultへのアクセス許可設定
- ✅ モジュール間の依存関係を自動解決

**実行コマンド**:

```powershell
# Bicepデプロイ（2.2と2.3で定義した構成をAzureに適用）
az deployment group create `
  --resource-group rg-az400-handson `
  --template-file infra/bicep/main.bicep `
  --parameters infra/bicep/parameters/dev.parameters.json

# デプロイ結果の確認
az resource list --resource-group rg-az400-handson --output table
```

**期待される出力**:
```
Name                          ResourceGroup      Location    Type
----------------------------  -----------------  ----------  ----------------------------------
az400-dev-webapp              rg-az400-handson   japaneast   Microsoft.Web/sites
az400-dev-kv                  rg-az400-handson   japaneast   Microsoft.KeyVault/vaults
az400-dev-plan                rg-az400-handson   japaneast   Microsoft.Web/serverfarms
...
```

**確認ポイント**:
- ✅ Web Appが作成されている
- ✅ Managed Identityが有効化されている（次のコマンドで確認）

```powershell
# Managed Identity確認
az webapp identity show `
  --name az400-dev-webapp `
  --resource-group rg-az400-handson `
  --query principalId -o tsv
```

**Azure RBAC ロール割り当て確認**:

```powershell
# Key Vault のリソースIDを取得
$KV_ID = az keyvault show `
  --name az400-dev-kv `
  --resource-group rg-az400-handson `
  --query id -o tsv

# RBAC ロール割り当て確認
az role assignment list `
  --scope $KV_ID `
  --query "[].{Role:roleDefinitionName, Principal:principalName, Type:principalType}" `
  --output table
```

**期待される出力**:
```
Role                          Principal            Type
----------------------------  -------------------  ----------------
Key Vault Secrets User        az400-dev-webapp     ServicePrincipal
Key Vault Administrator       az400-dev-webapp     ServicePrincipal
```

**確認ポイント**:
- ✅ `Key Vault Secrets User` が付与されている（シークレット読み取り権限）
- ✅ `Key Vault Administrator` が付与されている（管理権限）
- ✅ `PrincipalType` が `ServicePrincipal`（Managed Identity）

**🛡️ Microsoft Defender for Cloud アラート解消確認**:

このデプロイにより、以下のセキュリティ推奨が適用されました：
- ✅ Azure RBAC方式を使用（Access Policies から移行）
- ✅ 最小権限の原則（必要なロールのみ付与）
- ✅ Managed Identity認証（パスワード不要）

> 💡 **Note**: Defender for Cloud のアラートが消えるまで最大24時間かかる場合があります。

---

## 📋 午後セッション（2-3時間）

### ステップ 3: Application Insights統合（90分）

#### 3.1 Bicepモジュール定義: Application Insights

**目的**: Application Insightsリソースを定義するBicepモジュールを作成します。

> ⚠️ **注意**: このセクションではファイルを**作成**します。デプロイは **3.3** で実行します。

**infra/bicep/modules/appinsights.bicep**:

```bicep
@description('Application Insights名')
param appInsightsName string

@description('ロケーション')
param location string = resourceGroup().location

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    RetentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output appInsightsName string = appInsights.name
output instrumentationKey string = appInsights.properties.InstrumentationKey
output connectionString string = appInsights.properties.ConnectionString
```

**ポイント**:
- `kind: 'web'`: Webアプリケーション用のApplication Insights
- `RetentionInDays: 30`: テレメトリデータの保持期間（30日間）
- `connectionString`: アプリケーションから接続するための接続文字列（3.2で使用）
- このファイルは **3.3でデプロイ** します

---

#### 3.2 Webアプリケーション実装

**目的**: Application Insightsと統合したNode.js Webアプリケーションを実装します。

> ⚠️ **注意**: このセクションではファイルを**作成**します。デプロイは **3.3** で実行します。

**src/webapp/app.js**:

```javascript
const express = require('express');
const appInsights = require('applicationinsights');
const { DefaultAzureCredential } = require('@azure/identity');
const { SecretClient } = require('@azure/keyvault-secrets');

// Application Insights初期化
const connectionString = process.env.APPLICATIONINSIGHTS_CONNECTION_STRING;
if (connectionString) {
  appInsights.setup(connectionString);
  appInsights.start();
  console.log('Application Insights initialized');
}

const app = express();
const port = process.env.PORT || 3000;

// Key Vaultクライアント
const keyVaultUrl = process.env.KEY_VAULT_URL;
const credential = new DefaultAzureCredential();
const secretClient = new SecretClient(keyVaultUrl, credential);

// ルート
app.get('/', (req, res) => {
  // カスタムメトリクス送信
  const client = appInsights.defaultClient;
  client.trackEvent({ name: 'HomePage_Accessed' });
  client.trackMetric({ name: 'HomePage_ResponseTime', value: Date.now() });
  
  res.send('AZ-400 Handson Web App - Running!');
});

// Key Vaultテスト
app.get('/secret', async (req, res) => {
  try {
    const secretName = 'DatabaseConnectionString';
    const secret = await secretClient.getSecret(secretName);
    
    // セキュリティのため、実際の値は返さない
    res.json({
      secretName: secretName,
      retrieved: true,
      message: 'Secret retrieved from Key Vault successfully!'
    });
    
    // カスタムイベント送信
    appInsights.defaultClient.trackEvent({ name: 'Secret_Retrieved' });
  } catch (error) {
    console.error('Error retrieving secret:', error);
    res.status(500).json({ error: error.message });
    
    // エラー送信
    appInsights.defaultClient.trackException({ exception: error });
  }
});

// ヘルスチェック
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
```

**実装内容の説明**:

このWebアプリケーションは、**Application Insights**と**Key Vault**の統合を実証する3つのエンドポイントを提供します。

| エンドポイント | 機能 | Application Insights連携 |
|--------------|------|------------------------|
| **`GET /`** | ホームページ | ✅ カスタムイベント（`HomePage_Accessed`）<br>✅ カスタムメトリクス（`HomePage_ResponseTime`） |
| **`GET /secret`** | Key Vaultからシークレット取得<br>（Managed Identity認証） | ✅ カスタムイベント（`Secret_Retrieved`）<br>✅ 例外追跡（エラー時） |
| **`GET /health`** | ヘルスチェック | - |

**技術的ポイント**:
1. **Application Insights SDK統合**:
   - `appInsights.setup(connectionString)`: 環境変数から接続文字列を取得して初期化
   - `trackEvent()`: カスタムイベント送信（ユーザー操作追跡）
   - `trackMetric()`: カスタムメトリクス送信（パフォーマンス測定）
   - `trackException()`: 例外追跡（エラー分析）

2. **Managed Identity認証**:
   - `DefaultAzureCredential`: Azure環境で自動的にManaged Identityを使用
   - `SecretClient`: Key Vaultからシークレットを取得（パスワード不要）

3. **セキュリティ設計**:
   - `/secret` エンドポイントは取得成功のみ返し、実際のシークレット値は返さない
   - 環境変数経由で認証情報を注入（コードにハードコーディングしない）

**src/webapp/package.json**:

```json
{
  "name": "az400-webapp",
  "version": "1.0.0",
  "description": "AZ-400 Handson Web Application",
  "main": "app.js",
  "scripts": {
    "start": "node app.js",
    "test": "jest"
  },
  "dependencies": {
    "express": "^4.18.2",
    "applicationinsights": "^2.9.0",
    "@azure/identity": "^4.0.0",
    "@azure/keyvault-secrets": "^4.7.0"
  },
  "devDependencies": {
    "jest": "^29.7.0"
  },
  "keywords": ["az400", "devops"],
  "author": "",
  "license": "MIT"
}
```

**src/webapp/Dockerfile**:

```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 3000

CMD ["npm", "start"]
```

**ポイント**:
- `appInsights.setup(connectionString)`: Application Insights SDKの初期化
- `DefaultAzureCredential`: Managed IdentityでKey Vaultに認証
- `SecretClient`: Key Vaultからシークレットを取得
- Dockerfileでマルチステージビルド（本番依存関係のみインストール）
- **次の3.3でデプロイ** します

---

#### 3.3 デプロイ実行（3.1・3.2をAzureに適用）

**目的**: 3.1で定義したApplication Insightsと3.2で実装したWebアプリをAzureにデプロイします。

**デプロイ内容**:
- ✅ Application Insights（テレメトリ収集）
- ✅ Dockerイメージビルド & Azure Container Registry（ACR）へプッシュ
- ✅ Web AppへのコンテナデプロイHubからシークレット取得可能

> ⚠️ **前提条件**: Docker Desktopが起動していることを確認してください。  
> 起動していない場合: `Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"` で起動後、30-60秒待機してください。  
> 確認コマンド: `docker version`

**実行コマンド**:

```powershell
# ========================================
# 1. 依存関係インストール
# ========================================
cd src/webapp
npm install

# ========================================
# 2. Dockerイメージビルド（3.2のアプリをコンテナ化）
# ========================================
docker build -t az400webapp:latest .

# ========================================
# 3. Azure Container Registry作成
# ========================================
az acr create `
  --name az400acr `
  --resource-group rg-az400-handson `
  --sku Basic `
  --admin-enabled true

# ========================================
# 4. ACRにイメージをプッシュ
# ========================================
az acr login --name az400acr
docker tag az400webapp:latest az400acr.azurecr.io/az400webapp:latest
docker push az400acr.azurecr.io/az400webapp:latest

Write-Host "✅ Dockerイメージをプッシュしました" -ForegroundColor Green

# ========================================
# 5. Web AppにコンテナをデプロイHubにデプロイ
# ========================================
$ACR_USERNAME = az acr credential show --name az400acr --query username -o tsv
$ACR_PASSWORD = az acr credential show --name az400acr --query "passwords[0].value" -o tsv

az webapp config container set `
  --name az400-dev-webapp `
  --resource-group rg-az400-handson `
  --docker-custom-image-name az400acr.azurecr.io/az400webapp:latest `
  --docker-registry-server-url https://az400acr.azurecr.io `
  --docker-registry-server-user $ACR_USERNAME `
  --docker-registry-server-password $ACR_PASSWORD

# Web App再起動
az webapp restart --name az400-dev-webapp --resource-group rg-az400-handson

Write-Host "✅ Web Appにデプロイ完了" -ForegroundColor Green
Write-Host "🌐 URL: https://az400-dev-webapp.azurewebsites.net" -ForegroundColor Cyan
```

**確認ポイント**:
- ✅ Dockerイメージがビルドされている
- ✅ ACRにイメージがプッシュされている
- ✅ Web AppがACRからイメージをプルしてデプロイされている
- ✅ Application InsightsにテレメトリHubにテレメトリが送信されている（次のステップ4で確認）

**動作確認**:
```powershell
# ヘルスチェック
Invoke-RestMethod -Uri "https://az400-dev-webapp.azurewebsites.net/health"

# シークレット取得テスト（Managed Identity動作確認）
Invoke-RestMethod -Uri "https://az400-dev-webapp.azurewebsites.net/secret"
```

---

### ステップ 4: KQL実践（60分）

**実施場所**: Azure Portal → Application Insights → Logs（ログ）

**実施方法**:
1. **Azure Portalにアクセス**: [https://portal.azure.com](https://portal.azure.com)
2. **Application Insightsを開く**: リソースグループ `rg-az400-handson` → `az400-dev-ai`
3. **Logsを開く**: 左メニュー「監視」セクション → **Logs（ログ）**
4. **KQLクエリを実行**: 下記のクエリをコピー&ペーストして「実行」ボタンをクリック

> 💡 **ヒント**: `scripts/kql/basic-queries.kql` からクエリをコピーして、Azure Portal上で1つずつ実行してください。

---

#### 4.1 基本クエリ

**scripts/kql/basic-queries.kql**:

```kql
// ========================================
// AZ-400 Application Insights KQL練習
// ========================================

// 1️⃣ 時間集計: bin() - 1時間ごとのリクエスト数
requests
| where timestamp > ago(24h)
| summarize RequestCount = count() by bin(timestamp, 1h)
| render timechart

// 2️⃣ カラム追加: extend - レスポンスタイムをミリ秒に変換
requests
| where timestamp > ago(1h)
| extend duration_ms = duration
| project timestamp, name, duration_ms, success

// 3️⃣ カラム選択: project - 必要なカラムのみ表示
requests
| where timestamp > ago(1h)
| project timestamp, url, resultCode, duration

// 4️⃣ パーセンタイル: percentile() - 95パーセンタイルのレスポンスタイム
requests
| where timestamp > ago(1h)
| summarize 
    p50 = percentile(duration, 50),
    p95 = percentile(duration, 95),
    p99 = percentile(duration, 99)
| project 
    Median = p50,
    P95 = p95,
    P99 = p99

// 5️⃣ エラー率計算
requests
| where timestamp > ago(1h)
| extend isError = toint(success == false)
| summarize 
    TotalRequests = count(),
    ErrorCount = sum(isError),
    ErrorRate = 100.0 * sum(isError) / count()
| project TotalRequests, ErrorCount, ErrorRate

// 6️⃣ カスタムイベント集計
customEvents
| where timestamp > ago(24h)
| where name == "HomePage_Accessed"
| summarize count() by bin(timestamp, 1h)
| render timechart

// 7️⃣ 例外分析
exceptions
| where timestamp > ago(24h)
| summarize count() by outerMessage
| order by count_ desc

// 8️⃣ 複雑なクエリ: extend + project + percentile
requests
| where timestamp > ago(1h)
| extend duration_ms = duration
| summarize 
    RequestCount = count(),
    AvgDuration = avg(duration_ms),
    P95Duration = percentile(duration_ms, 95)
    by bin(timestamp, 5m), name
| project timestamp, name, RequestCount, AvgDuration, P95Duration
| order by timestamp desc
```

---

**各クエリの解説**:

| # | クエリ名 | 指示内容 | 結果の見方 |
|---|---------|---------|----------|
| **1️⃣** | **時間集計: bin()** | 過去24時間のリクエストを1時間ごとに集計 | **時系列グラフ**: 横軸=時刻、縦軸=リクエスト数<br>💡 トラフィックのピーク時間帯を特定 |
| **2️⃣** | **カラム追加: extend** | `duration`カラムを`duration_ms`として複製<br>（既存カラムはそのまま残る） | **テーブル**: timestamp, name, duration_ms, success<br>💡 元の`duration`も残っている（extendの特性） |
| **3️⃣** | **カラム選択: project** | timestamp, url, resultCode, durationのみ表示 | **テーブル**: 指定した4カラムのみ<br>💡 他のカラムは非表示（projectの特性） |
| **4️⃣** | **パーセンタイル** | 過去1時間のレスポンスタイムを50/95/99パーセンタイルで集計 | **1行の結果**:<br>• Median（中央値）: 50%のリクエストがこの時間以内<br>• P95: 95%のリクエストがこの時間以内<br>• P99: 99%のリクエストがこの時間以内<br>💡 **P95が試験頻出** |
| **5️⃣** | **エラー率計算** | 過去1時間の総リクエスト数、エラー数、エラー率を計算 | **1行の結果**:<br>• TotalRequests: 100<br>• ErrorCount: 5<br>• ErrorRate: 5.0（%）<br>💡 SLO監視に使用 |
| **6️⃣** | **カスタムイベント集計** | `HomePage_Accessed`イベントを1時間ごとに集計 | **時系列グラフ**: ホームページアクセス数の推移<br>💡 3.2で実装した`trackEvent()`の結果を可視化 |
| **7️⃣** | **例外分析** | 過去24時間の例外をメッセージ別に集計、多い順にソート | **テーブル**: 例外メッセージと発生回数<br>💡 最も頻繁に発生するエラーを特定 |
| **8️⃣** | **複雑なクエリ** | 5分間隔で、エンドポイント別にリクエスト数、平均時間、P95を集計 | **テーブル**: timestamp, name（エンドポイント）, RequestCount, AvgDuration, P95Duration<br>💡 エンドポイントごとのパフォーマンス監視 |

---

**実行時の注意点**:

| ポイント | 説明 |
|---------|------|
| **データがない場合** | クエリ実行前に、Web Appにアクセス（`Invoke-RestMethod`）してテレメトリを生成してください |
| **時間範囲** | `ago(1h)` = 過去1時間、`ago(24h)` = 過去24時間 |
| **グラフ vs テーブル** | `render timechart`がある→時系列グラフ表示<br>ない→テーブル表示 |
| **AZ-400試験対策** | クエリ **4️⃣（パーセンタイル）** と **5️⃣（エラー率）** が頻出 |

---

#### 4.2 試験頻出ポイント

**extendとprojectの違い**:

```kql
// extend: カラム追加（既存カラムも残る）
requests
| extend duration_ms = duration
| project timestamp, duration, duration_ms  // 元のdurationも表示可能

// project: カラム選択（指定したカラムのみ）
requests
| project timestamp, duration  // durationのみ表示
```

**パーセンタイルの意味**:

```
95パーセンタイル = 95%のリクエストがこの時間以内に完了
（上位5%の遅いリクエストを除外した値）

試験ひっかけポイント:
Q: "95%のユーザーのレスポンスタイムを確認したい"
A: percentile(duration, 95) を使用
```

---

## ✅ Day 2 成果物チェックリスト

### Key Vault
- [ ] Key Vault作成（Bicep）
- [ ] Access Policies設定（データプレーン）
- [ ] IAM設定（管理プレーン）
- [ ] IAMとAccess Policiesの違い完全理解

### Managed Identity
- [ ] system-assigned Managed Identity実装
- [ ] Web AppからKey Vault参照成功
- [ ] system/user-assignedの使い分け理解

### Application Insights
- [ ] Application Insights作成（Bicep）
- [ ] Web AppにSDK統合
- [ ] カスタムメトリクス送信確認
- [ ] カスタムイベント送信確認

### KQL
- [ ] bin()で時間集計
- [ ] extend/projectの違い理解
- [ ] percentile()で95パーセンタイル取得
- [ ] エラー率計算

### 理解度確認

以下の質問に即答できるか確認：

1. **Key VaultでIAMとAccess Policiesの使い分けは？**
   - Answer: IAM=管理プレーン（KV自体の管理）、Access Policies=データプレーン（シークレット操作）

2. **system-assignedとuser-assignedの違いは？**
   - Answer: system=1対1、user=複数リソースで共有可能

3. **95パーセンタイルの意味は？**
   - Answer: 95%のリクエストがこの時間以内に完了

4. **extendとprojectの違いは？**
   - Answer: extend=カラム追加、project=カラム選択

---

## 🎓 試験対策ポイント

### Day 2で克服した弱点領域

✅ **Key Vault IAM vs Access Policies**（最重要）  
✅ **Managed Identity: system vs user-assigned**  
✅ **KQLクエリ（bin/extend/project/percentile）**  
✅ **Application Insights カスタムメトリクス**

### 次のステップ

明日（Day 3）は **CI/CD完全マスター** を実践します：
- GitHub Actions実装
- Azure Pipelines実装
- 両者の比較・使い分け理解

---

**Day 2お疲れ様でした！最終日も頑張りましょう！🚀**
