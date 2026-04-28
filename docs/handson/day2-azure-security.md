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

// シークレット作成（サンプル）
resource secret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'DatabaseConnectionString'
  properties: {
    value: 'Server=tcp:sample.database.windows.net,1433;Database=mydb;'
  }
}

output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
```

**重要ポイント**:
- `enableRbacAuthorization: false` → Access Policies使用
- `accessPolicies` → データプレーン権限（シークレット読み取り）
- IAM（管理プレーン）は Azure Portal または Bicep の roleAssignment で設定

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
