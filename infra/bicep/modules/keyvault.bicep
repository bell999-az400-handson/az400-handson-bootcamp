@description('Key Vault名')
param keyVaultName string

@description('ロケーション')
param location string = resourceGroup().location

@description('テナントID')
param tenantId string = subscription().tenantId

@description('Managed IdentityのオブジェクトID（Access Policy用）')
param managedIdentityObjectId string

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
    // enablePurgeProtection は削除（一度有効化すると無効化不可のため）
    
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
          keys: []
          certificates: []
        }
      }
    ]
    
    // 🔒 セキュリティ: ネットワークアクセス制限
    // 本番環境では defaultAction: 'Deny' を推奨
    // ローカル開発環境からアクセスする場合は 'Allow' または特定IPを許可
    networkAcls: {
      defaultAction: 'Allow'  // 開発用: 'Deny'に変更して特定IPのみ許可することを推奨
      bypass: 'AzureServices'
    }
  }
}

// 🔒 セキュリティ注意: 以下はハンズオン学習用のサンプルシークレットです
// 本番環境では、シークレット値をBicepファイルにハードコードしないでください
// 推奨: Azure Portal、Azure CLI、または secure parameters を使用

// サンプルシークレット
resource sampleSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'DatabaseConnectionString'
  properties: {
    value: 'Server=tcp:sample.${environment().suffixes.sqlServerHostname},1433;Database=sampledb;User ID=admin;Password=P@ssw0rd;Encrypt=true;'
  }
}

resource apiKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'ApiKey'
  properties: {
    value: 'sample-api-key-12345'
  }
}

output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output keyVaultId string = keyVault.id
