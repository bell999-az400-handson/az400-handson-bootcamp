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
    enableRbacAuthorization: true   // ✅ Azure RBAC使用（Microsoft推奨）
    enableSoftDelete: true
    softDeleteRetentionInDays: 30
    // enablePurgeProtection は削除（一度有効化すると無効化不可のため）
    
    // データプレーン権限は Access Policies ではなく Azure RBAC で管理
    // accessPolicies は使用しない（RBAC有効化時は不要）
    
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

// ============================================
// Azure RBAC ロール割り当て（データプレーン + 管理プレーン）
// ============================================

// データプレーン権限: Key Vault Secrets User
// シークレットの読み取り専用アクセス（get, list）
var keyVaultSecretsUserRole = '4633458b-17de-408a-b874-0445c86b69e6'

resource keyVaultSecretsRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, managedIdentityObjectId, keyVaultSecretsUserRole)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRole)
    principalId: managedIdentityObjectId
    principalType: 'ServicePrincipal'
  }
}

output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output keyVaultId string = keyVault.id
