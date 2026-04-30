targetScope = 'resourceGroup'

@description('環境名（dev/staging/prod）')
@minLength(3)
param environmentName string = 'dev'

@description('ロケーション')
param location string = resourceGroup().location

@description('リソース名のプレフィックス')
param resourcePrefix string = 'az400'

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${resourcePrefix}${environmentName}st'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
  }
}

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: '${resourcePrefix}-${environmentName}-asp'
  location: location
  sku: {
    name: 'F1'
    tier: 'Free'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// Application Insights
module appInsights 'modules/appinsights.bicep' = {
  name: 'appInsightsDeployment'
  params: {
    appInsightsName: '${resourcePrefix}-${environmentName}-ai'
    location: location
  }
}

// Web App（Managed Identity付き） - Key Vault参照なしで先にデプロイ
module webApp 'modules/webapp.bicep' = {
  name: 'webAppDeployment'
  params: {
    webAppName: '${resourcePrefix}-${environmentName}-webapp'
    appServicePlanId: appServicePlan.id
    location: location
    appInsightsConnectionString: appInsights.outputs.connectionString
  }
}

// Key Vault - Web AppのManaged Identityを使用
module keyVault 'modules/keyvault.bicep' = {
  name: 'keyVaultDeployment'
  params: {
    keyVaultName: '${resourcePrefix}-${environmentName}-kv'
    location: location
    managedIdentityObjectId: webApp.outputs.managedIdentityPrincipalId
  }
}

// Outputs
output storageAccountName string = storageAccount.name
output appServicePlanName string = appServicePlan.name
output webAppName string = webApp.outputs.webAppName
output webAppUrl string = 'https://${webApp.outputs.webAppName}.azurewebsites.net'
output keyVaultName string = keyVault.outputs.keyVaultName
output appInsightsName string = appInsights.outputs.appInsightsName
