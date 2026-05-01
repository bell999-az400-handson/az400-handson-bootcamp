# セキュアなKey Vault設定のセットアップ

このスクリプトは、シークレット設定スクリプトに実行権限を付与します。

Write-Host "🔧 セキュアスクリプトのセットアップ中..." -ForegroundColor Green

# Git Bashが利用可能かチェック
$gitBashPath = "C:\Program Files\Git\bin\bash.exe"

if (Test-Path $gitBashPath) {
    Write-Host "✅ Git Bash が見つかりました" -ForegroundColor Green
    
    # Bashスクリプトに実行権限を付与
    $scriptPath = "scripts/setup/set-keyvault-secrets.sh"
    
    & $gitBashPath -c "chmod +x $scriptPath"
    
    Write-Host "✅ 実行権限を付与しました: $scriptPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "📝 次のステップ:" -ForegroundColor Cyan
    Write-Host "  1. Azure CLIでログイン: az login"
    Write-Host "  2. Bicepデプロイを完了"
    Write-Host "  3. スクリプトを実行:"
    Write-Host "     Git Bash: ./scripts/setup/set-keyvault-secrets.sh"
    Write-Host "     または"
    Write-Host "     bash scripts/setup/set-keyvault-secrets.sh"
} else {
    Write-Host "⚠️  Git Bash が見つかりません" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📝 手動でセットアップする場合:" -ForegroundColor Cyan
    Write-Host "  1. Git Bash を開く"
    Write-Host "  2. 以下のコマンドを実行:"
    Write-Host "     chmod +x scripts/setup/set-keyvault-secrets.sh"
    Write-Host "     ./scripts/setup/set-keyvault-secrets.sh"
}

Write-Host ""
Write-Host "🔒 セキュリティ確認:" -ForegroundColor Yellow
Write-Host "  ✓ スクリプト自体にシークレットは含まれていません"
Write-Host "  ✓ 実行時に安全に入力されます"
Write-Host "  ✓ GitHub にコミット可能です"
