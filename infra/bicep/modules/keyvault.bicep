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

// 🔒 セキュリティベストプラクティス:
// シークレット値はBicepファイルにハードコードしません
// デプロイ後に Azure CLI または Azure Portal を使用して安全に設定してください
// 手順は docs/handson/day2-azure-security.md の「1.4 シークレットの安全な設定」を参照

// 管理プレーン権限: IAM（RBAC）
// Key Vault Administrator ロールを Managed Identity に付与
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

output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output keyVaultId string = keyVault.id
