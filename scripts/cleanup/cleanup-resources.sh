#!/bin/bash

# ========================================
# AZ-400 Handson: リソース削除スクリプト
# ========================================

set -e

RESOURCE_GROUP="rg-az400-handson"

echo "========================================="
echo "AZ-400 Handson: Cleanup Resources"
echo "========================================="

echo ""
echo "⚠️  以下のリソースグループを削除します:"
echo "  - $RESOURCE_GROUP"
echo ""
read -p "本当に削除しますか？ (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "❌ キャンセルしました"
    exit 0
fi

echo ""
echo "🗑️  リソースグループ削除中..."
az group delete --name $RESOURCE_GROUP --yes --no-wait

echo "✅ 削除リクエスト送信完了"
echo "   バックグラウンドで削除が進行中です"
echo ""
echo "削除状況確認:"
echo "  az group show --name $RESOURCE_GROUP"
echo ""
