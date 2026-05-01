#!/bin/bash
#
# セキュアなKey Vaultシークレット設定スクリプト
# 
# セキュリティ対策:
# - パスワード入力は非表示(-s)
# - 履歴に記録されない
# - 使用後に変数をクリア
# - デバッグモード無効
# - エラー時にシークレット値を表示しない
#

set -e  # エラーで停止
set -u  # 未定義変数でエラー
set -o pipefail  # パイプラインのエラーを検知

# デバッグモード無効（パスワード漏洩防止）
set +x

# 履歴に記録しない（重要）
HISTFILE=/dev/null
set +o history

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# クリーンアップ関数（終了時に変数をクリア）
cleanup() {
  unset SQL_PASSWORD
  unset CONNECTION_STRING
  unset CONNECTION_STRING_MI
  unset API_KEY
  echo -e "${YELLOW}🧹 メモリから機密情報をクリアしました${NC}"
}
trap cleanup EXIT

# エラーハンドラー（シークレット値を表示しない）
error_handler() {
  echo -e "${RED}❌ エラーが発生しました (line $1)${NC}" >&2
  echo "詳細はログを確認してください（機密情報は表示されません）"
  exit 1
}
trap 'error_handler $LINENO' ERR

# ========================================
# 設定
# ========================================
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-az400-handson}"
SQL_SERVER_NAME="${SQL_SERVER_NAME:-az400-dev-sqlserver}"
SQL_DATABASE_NAME="${SQL_DATABASE_NAME:-az400db}"
SQL_ADMIN_USER="${SQL_ADMIN_USER:-sqladmin}"

echo -e "${GREEN}🔐 Key Vaultシークレット設定スクリプト${NC}"
echo "================================================"

# ========================================
# Key Vault名を取得
# ========================================
echo "📦 Key Vault名を取得中..."
KEY_VAULT_NAME=$(az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name main \
  --query properties.outputs.keyVaultName.value -o tsv 2>/dev/null || echo "")

if [ -z "$KEY_VAULT_NAME" ]; then
  echo -e "${RED}❌ Key Vaultが見つかりません${NC}"
  echo "先にBicepデプロイを完了してください"
  exit 1
fi

echo -e "${GREEN}✅ Key Vault: $KEY_VAULT_NAME${NC}"

# ========================================
# Azure SQL Database接続文字列設定
# ========================================
echo ""
echo "📊 SQL Server接続文字列を設定します"
echo "SQL Server: $SQL_SERVER_NAME"

# SQL Server FQDNを取得
SQL_FQDN=$(az sql server show \
  --name "$SQL_SERVER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query fullyQualifiedDomainName -o tsv 2>/dev/null || echo "")

if [ -z "$SQL_FQDN" ]; then
  echo -e "${YELLOW}⚠️  SQL Serverが見つかりません。スキップします。${NC}"
else
  echo "SQL Server FQDN: $SQL_FQDN"
  
  # パスワードを安全に入力（非表示）
  echo ""
  read -sp "🔑 SQL管理者パスワード ($SQL_ADMIN_USER) を入力: " SQL_PASSWORD
  echo ""
  
  # パスワード検証（空でないこと）
  if [ -z "$SQL_PASSWORD" ]; then
    echo -e "${RED}❌ パスワードが入力されていません${NC}"
    exit 1
  fi
  
  # 接続文字列を構築（セキュアに）
  CONNECTION_STRING="Server=tcp:${SQL_FQDN},1433;Database=${SQL_DATABASE_NAME};User ID=${SQL_ADMIN_USER};Password=${SQL_PASSWORD};Encrypt=true;TrustServerCertificate=false;Connection Timeout=30;"
  
  # Key Vaultに設定（出力を抑制）
  echo "💾 DatabaseConnectionString を設定中..."
  az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name DatabaseConnectionString \
    --value "$CONNECTION_STRING" \
    --output none 2>&1 | grep -v "value" || true
  
  echo -e "${GREEN}✅ DatabaseConnectionString を設定しました${NC}"
  
  # Managed Identity用（パスワード不要）
  CONNECTION_STRING_MI="Server=tcp:${SQL_FQDN},1433;Database=${SQL_DATABASE_NAME};Authentication=Active Directory Default;Encrypt=true;"
  
  echo "💾 DatabaseConnectionStringMI を設定中..."
  az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name DatabaseConnectionStringMI \
    --value "$CONNECTION_STRING_MI" \
    --output none
  
  echo -e "${GREEN}✅ DatabaseConnectionStringMI を設定しました${NC}"
  
  # 即座にパスワードと接続文字列をクリア
  unset SQL_PASSWORD
  unset CONNECTION_STRING
  unset CONNECTION_STRING_MI
fi

# ========================================
# その他のシークレット設定
# ========================================
echo ""
echo "📝 その他のシークレットを設定します"

# 環境変数からAPIキーを設定（オプション）
if [ -n "${API_KEY:-}" ]; then
  echo "💾 ApiKey を設定中..."
  az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name ApiKey \
    --value "$API_KEY" \
    --output none
  echo -e "${GREEN}✅ ApiKey を設定しました${NC}"
  unset API_KEY
else
  echo -e "${YELLOW}⚠️  環境変数 API_KEY が未設定。スキップします。${NC}"
fi

# ========================================
# 設定確認（値は表示しない）
# ========================================
echo ""
echo "🔍 設定されたシークレット一覧（値は表示されません）:"
az keyvault secret list \
  --vault-name "$KEY_VAULT_NAME" \
  --query "[].{Name:name, Enabled:attributes.enabled, Updated:attributes.updated}" \
  --output table

echo ""
echo -e "${GREEN}✅ すべてのシークレット設定が完了しました！${NC}"
echo ""
echo "⚠️  セキュリティ注意事項:"
echo "  - このスクリプトは .gitignore に含めないでください"
echo "  - 実行後、ターミナル履歴をクリアすることを推奨します: history -c"
echo "  - 本番環境では、CI/CDパイプラインから実行してください"

# 履歴を再度有効化
set -o history
