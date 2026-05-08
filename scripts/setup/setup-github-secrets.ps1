# setup-github-secrets.ps1
# GitHub Secretsを対話的に設定するスクリプト
# 
# 用途: AZ-400ハンズオン用のGitHub Secretsを安全に設定
# セキュリティ: クリップボード経由でファイルを作成せず、機密情報を扱う

# ========================================
# 1. 前提条件チェック
# ========================================

# GitHub CLIがインストールされているか確認
# GitHub CLIは'gh'コマンドでGitHub操作を行うツール
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "❌ GitHub CLI がインストールされていません" -ForegroundColor Red
    Write-Host "https://cli.github.com/ からインストールしてください"
    exit 1
}

# ========================================
# 2. GitHub認証確認
# ========================================

# ログイン確認
# GitHub CLIが認証されているかチェック
gh auth status
if ($LASTEXITCODE -ne 0) {
    Write-Host "GitHub CLIでログインしてください"
    gh auth login
}

Write-Host "🔐 GitHub Secrets を設定します" -ForegroundColor Green
Write-Host ""

# ========================================
# 3. Azure認証情報の設定
# ========================================

# AZURE_CREDENTIALS: Azureサービスプリンシパル認証情報（JSON形式）
# - GitHub ActionsからAzureにログインするために必要
# - セキュリティ: ファイルではなくクリップボードから直接設定
# - 前提: 事前に`az ad sp create-for-rbac --sdk-auth | Set-Clipboard`を実行済み
Write-Host "📋 ステップ1でクリップボードにコピーした Azure認証情報を使用します" -ForegroundColor Cyan
$useClipboard = Read-Host "クリップボードから設定しますか？ (y/n, Enter でスキップ)"
if ($useClipboard -eq 'y') {
    # クリップボードの内容をそのままGitHub Secretに設定
    Get-Clipboard | gh secret set AZURE_CREDENTIALS
    Write-Host "✅ AZURE_CREDENTIALS を設定しました" -ForegroundColor Green
    
    # セキュリティのためクリップボードをクリア
    # 機密情報がクリップボードに残らないようにする
    Set-Clipboard -Value ""
    Write-Host "🔒 クリップボードをクリアしました" -ForegroundColor Green
}

# ========================================
# 4. SQL Server接続情報の設定
# ========================================

# SQL_SERVER_FQDN: SQL Serverの完全修飾ドメイン名
# - 形式: <server-name>.database.windows.net
# - 取得方法: az sql server show --query fullyQualifiedDomainName
Write-Host ""
Write-Host "💾 SQL Server接続情報を設定します" -ForegroundColor Cyan
$sqlServerFqdn = Read-Host "SQL Server FQDN (Enter でスキップ)"
if ($sqlServerFqdn) {
    gh secret set SQL_SERVER_FQDN -b $sqlServerFqdn
    Write-Host "✅ SQL_SERVER_FQDN を設定しました" -ForegroundColor Green
}

# SQL_DATABASE_NAME: データベース名
# - 例: az400db, handson-database など
$sqlDbName = Read-Host "SQL Database名 (Enter でスキップ)"
if ($sqlDbName) {
    gh secret set SQL_DATABASE_NAME -b $sqlDbName
    Write-Host "✅ SQL_DATABASE_NAME を設定しました" -ForegroundColor Green
}

# SQL_ADMIN_USER: SQL Server管理者のユーザー名
# - Bicepデプロイ時に設定した管理者名
# - 例: sqladmin, azureuser など
$sqlAdminUser = Read-Host "SQL管理者ユーザー名 (Enter でスキップ)"
if ($sqlAdminUser) {
    gh secret set SQL_ADMIN_USER -b $sqlAdminUser
    Write-Host "✅ SQL_ADMIN_USER を設定しました" -ForegroundColor Green
}

# ========================================
# 5. 機密情報の設定（SecureString使用）
# ========================================

# SQL_ADMIN_PASSWORD: SQL Server管理者のパスワード
# - セキュリティ: SecureStringで入力（画面にマスク表示）
# - コマンド履歴にも残らない
Write-Host ""
Write-Host "🔑 機密情報を設定します（入力は画面に表示されません）" -ForegroundColor Cyan
$sqlAdminPassword = Read-Host "SQL管理者パスワード (Enter でスキップ)" -AsSecureString
if ($sqlAdminPassword.Length -gt 0) {
    # SecureStringを平文に変換（メモリ上でのみ）
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlAdminPassword)
    )
    # GitHub Secretに設定
    gh secret set SQL_ADMIN_PASSWORD -b $plainPassword
    Write-Host "✅ SQL_ADMIN_PASSWORD を設定しました" -ForegroundColor Green
    
    # 変数をクリア（メモリから削除）
    $plainPassword = $null
}

# API_KEY: 外部APIキー（学習用）
# - このハンズオンでは学習目的のデモ値を使用
# - デモ値: demo-api-key-12345-for-learning
# - セキュリティ: SecureStringで入力（実際のAPIキーと同じ扱い）
Write-Host "学習用デモ値を設定する場合: demo-api-key-12345-for-learning" -ForegroundColor Yellow
$apiKey = Read-Host "API Key (Enter でスキップ)" -AsSecureString
if ($apiKey.Length -gt 0) {
    # SecureStringを平文に変換（メモリ上でのみ）
    $plainApiKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($apiKey)
    )
    # GitHub Secretに設定
    gh secret set API_KEY -b $plainApiKey
    Write-Host "✅ API_KEY を設定しました" -ForegroundColor Green
    
    # 変数をクリア（メモリから削除）
    $plainApiKey = $null
}

# ========================================
# 6. 設定確認
# ========================================

Write-Host ""
Write-Host "🔍 設定されたシークレット一覧:" -ForegroundColor Cyan
# GitHub Secretsのリストを表示（値は表示されず、名前と更新日時のみ）
gh secret list

# ========================================
# 7. 完了メッセージ
# ========================================

Write-Host ""
Write-Host "✅ GitHub Secrets の設定が完了しました！" -ForegroundColor Green
Write-Host ""
Write-Host "📌 次のステップ:" -ForegroundColor Yellow
Write-Host "  1. GitHub ActionsでWorkflowを実行してください" -ForegroundColor White
Write-Host "  2. リポジトリのActions タブから 'Deploy Secrets to Key Vault' を選択" -ForegroundColor White
Write-Host "  3. 'Run workflow' をクリックして環境（dev/staging/prod）を選択" -ForegroundColor White
