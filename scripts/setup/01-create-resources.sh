#!/bin/bash

# ========================================
# AZ-400 Handson: Azure リソース作成スクリプト
# ========================================

set -e  # エラー時に停止

# 変数設定
RESOURCE_GROUP="rg-az400-handson"
LOCATION="japaneast"
ENVIRONMENT="dev"

echo "========================================="
echo "AZ-400 Handson: Azure Resources Setup"
echo "========================================="

# Azure CLIログイン確認
if ! az account show &>/dev/null; then
    echo "❌ Azure CLIにログインしていません"
    echo "az login を実行してください"
    exit 1
fi

# サブスクリプション表示
SUBSCRIPTION=$(az account show --query name -o tsv)
echo "✅ サブスクリプション: $SUBSCRIPTION"

# リソースグループ作成
echo ""
echo "📦 リソースグループ作成中..."
if az group create --name $RESOURCE_GROUP --location $LOCATION --output none; then
    echo "✅ リソースグループ作成完了: $RESOURCE_GROUP"
else
    echo "⚠️  リソースグループはすでに存在します"
fi

# Bicepデプロイ
echo ""
echo "🚀 Bicepテンプレートデプロイ中..."
DEPLOYMENT_NAME="az400-deployment-$(date +%Y%m%d-%H%M%S)"

az deployment group create \
    --name $DEPLOYMENT_NAME \
    --resource-group $RESOURCE_GROUP \
    --template-file ../infra/bicep/main.bicep \
    --parameters ../infra/bicep/parameters/${ENVIRONMENT}.parameters.json \
    --output table

# デプロイ結果取得
echo ""
echo "📊 デプロイ結果:"
STORAGE_ACCOUNT=$(az deployment group show --name $DEPLOYMENT_NAME --resource-group $RESOURCE_GROUP --query properties.outputs.storageAccountName.value -o tsv)
WEB_APP_NAME=$(az deployment group show --name $DEPLOYMENT_NAME --resource-group $RESOURCE_GROUP --query properties.outputs.webAppName.value -o tsv)
KEY_VAULT_NAME=$(az deployment group show --name $DEPLOYMENT_NAME --resource-group $RESOURCE_GROUP --query properties.outputs.keyVaultName.value -o tsv)
APP_INSIGHTS_NAME=$(az deployment group show --name $DEPLOYMENT_NAME --resource-group $RESOURCE_GROUP --query properties.outputs.appInsightsName.value -o tsv)
WEB_APP_URL=$(az deployment group show --name $DEPLOYMENT_NAME --resource-group $RESOURCE_GROUP --query properties.outputs.webAppUrl.value -o tsv)

echo "  - Storage Account: $STORAGE_ACCOUNT"
echo "  - Web App: $WEB_APP_NAME"
echo "  - Key Vault: $KEY_VAULT_NAME"
echo "  - Application Insights: $APP_INSIGHTS_NAME"
echo "  - Web App URL: $WEB_APP_URL"

# Azure Container Registry作成
echo ""
echo "📦 Azure Container Registry作成中..."
ACR_NAME="az400acr"

if az acr create --name $ACR_NAME --resource-group $RESOURCE_GROUP --sku Basic --output none 2>/dev/null; then
    echo "✅ ACR作成完了: $ACR_NAME"
else
    echo "⚠️  ACRはすでに存在します: $ACR_NAME"
fi

# ACR admin有効化
az acr update --name $ACR_NAME --admin-enabled true --output none
echo "✅ ACR admin有効化完了"

# 環境変数ファイル作成
echo ""
echo "📝 環境変数ファイル作成中..."
cat > ../.env << EOF
# Azure Resources
RESOURCE_GROUP=$RESOURCE_GROUP
STORAGE_ACCOUNT=$STORAGE_ACCOUNT
WEB_APP_NAME=$WEB_APP_NAME
KEY_VAULT_NAME=$KEY_VAULT_NAME
APP_INSIGHTS_NAME=$APP_INSIGHTS_NAME
WEB_APP_URL=$WEB_APP_URL
ACR_NAME=$ACR_NAME

# Connection Strings
KEY_VAULT_URL=https://${KEY_VAULT_NAME}.vault.azure.net/
APPLICATIONINSIGHTS_CONNECTION_STRING=$(az monitor app-insights component show --app $APP_INSIGHTS_NAME --resource-group $RESOURCE_GROUP --query connectionString -o tsv)

# ACR Credentials
ACR_LOGIN_SERVER=${ACR_NAME}.azurecr.io
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv)
EOF

echo "✅ 環境変数ファイル作成完了: .env"

echo ""
echo "========================================="
echo "✅ すべてのリソース作成完了！"
echo "========================================="
echo ""
echo "次のステップ:"
echo "1. GitHub Secretsに以下の値を設定:"
echo "   - ACR_LOGIN_SERVER: ${ACR_NAME}.azurecr.io"
echo "   - ACR_USERNAME: $(az acr credential show --name $ACR_NAME --query username -o tsv)"
echo "   - ACR_PASSWORD: (上記の.envファイルを参照)"
echo ""
echo "2. アプリケーションをビルド・デプロイ:"
echo "   cd ../src/webapp"
echo "   docker build -t ${ACR_NAME}.azurecr.io/az400webapp:latest ."
echo "   az acr login --name $ACR_NAME"
echo "   docker push ${ACR_NAME}.azurecr.io/az400webapp:latest"
echo ""
echo "3. Web Appにアクセス:"
echo "   $WEB_APP_URL"
echo ""
