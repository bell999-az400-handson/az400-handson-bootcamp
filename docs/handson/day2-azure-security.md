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

```bash
# ❌ NG例: Bicepファイルにシークレット値をハードコード（絶対禁止）
# resource secret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
#   properties: { value: 'my-secret-password-123' }  // 🚫 危険！
# }

# ✅ OK例: デプロイ後にAzure CLIで安全に設定
```

**手順1: Key Vaultデプロイ（シークレットなし）**

```bash
# Bicepデプロイ（シークレット値は含まない）
az deployment group create \
  --resource-group rg-az400-handson \
  --template-file infra/bicep/main.bicep \
  --parameters infra/bicep/parameters/dev.parameters.json

# Key Vault名を取得
KEY_VAULT_NAME=$(az deployment group show \
  --resource-group rg-az400-handson \
  --name main \
  --query properties.outputs.keyVaultName.value -o tsv)

echo "Key Vault名: $KEY_VAULT_NAME"
```

**手順2: Azure CLIでシークレットを安全に設定**

```bash
# 方法1: インタラクティブに入力（推奨）
az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name DatabaseConnectionString \
  --value "$(read -sp 'DB接続文字列を入力: ' SECRET && echo $SECRET)"

# 方法2: 環境変数から設定（CI/CDパイプライン用）
az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name ApiKey \
  --value "$API_KEY_SECRET"  # GitHub Secrets等から注入

# 方法3: ファイルから読み込み（.gitignore必須）
az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name SshPrivateKey \
  --file ~/.ssh/id_rsa  # ファイル内容をシークレットとして保存
```

**手順3: 設定確認（値は表示しない）**

```bash
# シークレット一覧（値は表示されない）
az keyvault secret list --vault-name $KEY_VAULT_NAME --output table

# 特定シークレットの存在確認（値は表示しない）
az keyvault secret show \
  --vault-name $KEY_VAULT_NAME \
  --name DatabaseConnectionString \
  --query "name" -o tsv

# ⚠️ 値を確認する場合（本番環境では慎重に）
az keyvault secret show \
  --vault-name $KEY_VAULT_NAME \
  --name DatabaseConnectionString \
  --query "value" -o tsv
```

**AZ-400試験ポイント**:

| シナリオ | 正しい方法 | 誤った方法 |
|---------|-----------|----------|
| Bicepでのシークレット管理 | デプロイ後にCLI設定 | ❌ Bicepにハードコード |
| GitHub Actionsからの設定 | GitHub Secrets → 環境変数 → az CLI | ❌ YAMLにパスワード記述 |
| ローカル開発環境 | .env（.gitignore済） → CLI設定 | ❌ コミット可能なファイルに保存 |
| CI/CDパイプライン | Variable Groups（暗号化） | ❌ パイプライン定義にプレーンテキスト |

**セキュアパラメータの使用（代替案）**:

```bicep
// シークレット値を外部パラメータから受け取る場合
@secure()
param databaseConnectionString string = ''  // デフォルト空文字

resource secret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (databaseConnectionString != '') {
  parent: keyVault
  name: 'DatabaseConnectionString'
  properties: {
    value: databaseConnectionString  // @secure()で保護
  }
}
```

```bash
# パラメータファイルで渡す場合（.gitignore必須）
az deployment group create \
  --parameters databaseConnectionString="$DB_CONNECTION_STRING"
```

**Git管理のベストプラクティス**:

```bash
# .gitignoreに追加（必須）
cat >> .gitignore << EOF
# シークレット関連ファイル（絶対コミット禁止）
*.secrets.json
*.secrets.*.json
.env
.env.local
**/appsettings.Development.json
EOF

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

```bash
# 1. Azure CLIでログイン
az login

# 2. リソースグループを環境変数に設定
export RESOURCE_GROUP="rg-az400-handson"

# 3. スクリプトを実行
./scripts/setup/set-keyvault-secrets.sh

# または
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

**必須シークレット**:

```bash
# 1. Azure認証情報を作成
az ad sp create-for-rbac \
  --name "github-actions-az400" \
  --role contributor \
  --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID>/resourceGroups/rg-az400-handson \
  --sdk-auth

# 出力されたJSONをGitHub SecretsのAZURE_CREDENTIALSに設定
```

**GitHub Secrets一覧**:

| シークレット名 | 説明 | 取得方法 |
|-------------|------|---------|
| `AZURE_CREDENTIALS` | Azure認証情報（JSON） | `az ad sp create-for-rbac --sdk-auth` |
| `SQL_SERVER_FQDN` | SQL Server FQDN | `az sql server show --query fullyQualifiedDomainName` |
| `SQL_DATABASE_NAME` | データベース名 | 例: `az400db` |
| `SQL_ADMIN_USER` | SQL管理者名 | 例: `sqladmin` |
| `SQL_ADMIN_PASSWORD` | SQL管理者パスワード | デプロイ時に設定した値 |
| `API_KEY` | 外部APIキー（オプション） | サードパーティから取得 |

**GitHub Secretsの設定方法**:

1. **Web UIで設定**:
   - リポジトリ → Settings → Secrets and variables → Actions
   - "New repository secret" をクリック
   - Name と Secret を入力して保存

2. **GitHub CLIで設定**:

```bash
# GitHub CLIインストール確認
gh --version

# ログイン
gh auth login

# シークレットを設定
gh secret set AZURE_CREDENTIALS < azure-credentials.json
gh secret set SQL_SERVER_FQDN -b "az400-dev-sqlserver.database.windows.net"
gh secret set SQL_DATABASE_NAME -b "az400db"
gh secret set SQL_ADMIN_USER -b "sqladmin"
gh secret set SQL_ADMIN_PASSWORD -b "YourSecurePassword123!"
gh secret set API_KEY -b "your-api-key-here"

# 確認
gh secret list
```

**ワークフロー実行手順**:

1. **GitHubリポジトリページに移動**
2. **Actionsタブをクリック**
3. **"Deploy Secrets to Key Vault"** ワークフローを選択
4. **"Run workflow"** をクリック
5. **環境を選択** (dev/staging/prod)
6. **"Run workflow"** を実行

**ワークフロー実行結果**:

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

**ワークフロー定義**: [.github/workflows/deploy-secrets.yml](../../.github/workflows/deploy-secrets.yml)

---

##### 方法3: Azure CLIでの個別設定

```bash
# Key Vault名を取得
KEY_VAULT_NAME=$(az deployment group show \
  --resource-group rg-az400-handson \
  --name main \
  --query properties.outputs.keyVaultName.value -o tsv)

# データベース接続文字列を自動生成
SQL_SERVER_FQDN=$(az sql server show \
  --name az400-dev-sqlserver \
  --resource-group rg-az400-handson \
  --query fullyQualifiedDomainName -o tsv)

DB_CONNECTION_STRING="Server=tcp:${SQL_SERVER_FQDN},1433;Database=az400db;Authentication=Active Directory Default;Encrypt=true;TrustServerCertificate=false;"

# シークレット設定
az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name DatabaseConnectionString \
  --value "$DB_CONNECTION_STRING" \
  --output none

# API Key設定（対話的）
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

#### 2.2 Web App with system-assigned Managed Identity

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

#### 2.3 main.bicep更新

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

#### 2.4 デプロイ実行

```bash
# Bicepデプロイ
az deployment group create \
  --resource-group rg-az400-handson \
  --template-file infra/bicep/main.bicep \
  --parameters infra/bicep/parameters/dev.parameters.json

# 確認
az resource list --resource-group rg-az400-handson --output table
```

---

## 📋 午後セッション（2-3時間）

### ステップ 3: Application Insights統合（90分）

#### 3.1 Application Insights Bicep

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

#### 3.2 サンプルWebアプリ実装

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

#### 3.3 デプロイ

```bash
# 依存関係インストール
cd src/webapp
npm install

# Dockerイメージビルド
docker build -t az400webapp:latest .

# Azure Container Registry作成（事前準備）
az acr create --name az400acr --resource-group rg-az400-handson --sku Basic

# ACRにプッシュ
az acr login --name az400acr
docker tag az400webapp:latest az400acr.azurecr.io/az400webapp:latest
docker push az400acr.azurecr.io/az400webapp:latest

# Web Appにデプロイ
az webapp config container set \
  --name az400-dev-webapp \
  --resource-group rg-az400-handson \
  --docker-custom-image-name az400acr.azurecr.io/az400webapp:latest
```

---

### ステップ 4: KQL実践（60分）

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
