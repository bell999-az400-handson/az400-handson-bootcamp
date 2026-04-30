@description('Web App名')
param webAppName string

@description('App Service Plan ID')
param appServicePlanId string

@description('ロケーション')
param location string = resourceGroup().location

@description('Application Insights Connection String')
param appInsightsConnectionString string

resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: webAppName
  location: location
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'  // 🔒 セキュリティ: system-assigned Managed Identity有効化
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true  // 🔒 セキュリティ: HTTPS通信のみ許可
    siteConfig: {
      linuxFxVersion: 'DOCKER|mcr.microsoft.com/appsvc/staticsite:latest'  // デフォルトイメージ
      alwaysOn: false  // Free tierではfalse必須
      ftpsState: 'Disabled'  // 🔒 セキュリティ: FTP無効化
      minTlsVersion: '1.2'  // 🔒 セキュリティ: TLS 1.2最小バージョン
      appSettings: [
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'DOCKER_ENABLE_CI'
          value: 'true'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'PORT'
          value: '3000'
        }
      ]
    }
  }
}

output webAppName string = webApp.name
output webAppHostName string = webApp.properties.defaultHostName
output managedIdentityPrincipalId string = webApp.identity.principalId
output webAppId string = webApp.id
