#!/bin/bash

# ========================================
# AZ-400 Handson: GitHub-Azure Boards連携スクリプト
# ========================================

echo "========================================="
echo "AZ-400 Handson: GitHub-Azure Boards Integration"
echo "========================================="

echo ""
echo "GitHub と Azure Boards の連携手順:"
echo ""
echo "1. Azure DevOps で GitHub 接続を追加"
echo "   - Azure DevOps > Project Settings > GitHub connections"
echo "   - 「New connection」をクリック"
echo "   - GitHubアカウントを認証"
echo ""
echo "2. GitHub リポジトリと Azure Boards を接続"
echo "   - Azure DevOps > Azure Boards > Settings > GitHub connections"
echo "   - リポジトリを選択して接続"
echo ""
echo "3. AB#記法の動作確認"
echo "   - コミットメッセージに「AB#<work-item-id>」を含める"
echo "   - 例: git commit -m \"feat: 新機能追加 AB#123\""
echo "   - Azure Boards で Work Item とコミットがリンクされることを確認"
echo ""
echo "4. PR と Work Item の連携確認"
echo "   - PR の本文に「AB#<work-item-id>」を含める"
echo "   - Azure Boards で Work Item と PR がリンクされることを確認"
echo ""
echo "公式ドキュメント:"
echo "  https://learn.microsoft.com/azure/devops/boards/github/"
echo ""

echo "========================================="
echo "✅ GitHub-Azure Boards連携ガイド完了！"
echo "========================================="
