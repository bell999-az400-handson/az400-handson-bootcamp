#!/bin/bash

# ========================================
# AZ-400 Handson: Azure DevOps設定スクリプト
# ========================================

set -e

echo "========================================="
echo "AZ-400 Handson: Azure DevOps Setup"
echo "========================================="

# Azure DevOps拡張機能確認
if ! az extension show --name azure-devops &>/dev/null; then
    echo "📦 Azure DevOps拡張機能をインストール中..."
    az extension add --name azure-devops
else
    echo "✅ Azure DevOps拡張機能インストール済み"
fi

# 組織とプロジェクト設定（ユーザー入力）
echo ""
read -p "Azure DevOps組織名を入力してください (例: https://dev.azure.com/your-org): " ORG_URL
read -p "プロジェクト名を入力してください: " PROJECT_NAME

# デフォルト設定
az devops configure --defaults organization=$ORG_URL project=$PROJECT_NAME

echo "✅ デフォルト設定完了"
echo "  - Organization: $ORG_URL"
echo "  - Project: $PROJECT_NAME"

# Service Connection作成（手動設定案内）
echo ""
echo "========================================="
echo "Service Connection設定（手動）"
echo "========================================="
echo ""
echo "以下のService Connectionを作成してください:"
echo ""
echo "1. Azure Resource Manager Service Connection"
echo "   - Name: AzureServiceConnection"
echo "   - Subscription: 使用するサブスクリプション"
echo "   - Resource Group: rg-az400-handson"
echo ""
echo "2. Docker Registry Service Connection"
echo "   - Name: ACRServiceConnection"
echo "   - Registry Type: Azure Container Registry"
echo "   - Subscription: 使用するサブスクリプション"
echo "   - Azure Container Registry: az400acr"
echo ""
echo "設定方法:"
echo "  Azure DevOps > Project Settings > Service connections > New service connection"
echo ""

# Branch Policy設定案内
echo ""
echo "========================================="
echo "Branch Policy設定（手動）"
echo "========================================="
echo ""
echo "main ブランチに以下のポリシーを設定してください:"
echo ""
echo "1. Require a minimum number of reviewers"
echo "   - Minimum number of reviewers: 1"
echo ""
echo "2. Build Validation"
echo "   - Build pipeline: azure-pipelines.yml"
echo "   - Policy requirement: Required"
echo ""
echo "3. Require linked work items"
echo "   - Required"
echo ""
echo "設定方法:"
echo "  Azure DevOps > Repos > Branches > main > Branch policies"
echo ""

echo "========================================="
echo "✅ Azure DevOps設定ガイド完了！"
echo "========================================="
