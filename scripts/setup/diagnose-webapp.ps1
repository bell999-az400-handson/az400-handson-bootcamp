# Azure Web App診断スクリプト
# 503エラーの原因を特定するための診断ツール

param(
    [string]$WebAppName = "az400-dev-webapp",
    [string]$ResourceGroup = "rg-az400-handson",
    [string]$ACRName = "az400acr"
)

Write-Host "=== Azure Web App 診断スクリプト ===" -ForegroundColor Cyan
Write-Host "Web App: $WebAppName" -ForegroundColor Yellow
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Yellow
Write-Host ""

# 1. Web Appの存在確認
Write-Host "[1] Web Appの存在確認..." -ForegroundColor Green
$webAppExists = az webapp show --name $WebAppName --resource-group $ResourceGroup 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ ERROR: Web App '$WebAppName' が見つかりません" -ForegroundColor Red
    Write-Host "利用可能なWeb Apps:" -ForegroundColor Yellow
    az webapp list --resource-group $ResourceGroup --query "[].{Name:name, State:state, Location:location}" -o table
    exit 1
}
Write-Host "✅ Web App が存在します" -ForegroundColor Green
Write-Host ""

# 2. Web Appの状態確認
Write-Host "[2] Web Appの状態確認..." -ForegroundColor Green
$state = az webapp show --name $WebAppName --resource-group $ResourceGroup --query "{State:state, AvailabilityState:availabilityState, UsageState:usageState}" -o json | ConvertFrom-Json
Write-Host "State: $($state.State)"
Write-Host "Availability: $($state.AvailabilityState)"
Write-Host "Usage: $($state.UsageState)"

if ($state.State -ne "Running") {
    Write-Host "⚠️  WARNING: Web App is not running!" -ForegroundColor Yellow
}
Write-Host ""

# 3. コンテナ設定確認
Write-Host "[3] コンテナ設定確認..." -ForegroundColor Green
az webapp config container show --name $WebAppName --resource-group $ResourceGroup
Write-Host ""

# 4. アプリケーション設定確認
Write-Host "[4] 重要なアプリケーション設定確認..." -ForegroundColor Green
$settings = az webapp config appsettings list --name $WebAppName --resource-group $ResourceGroup | ConvertFrom-Json
$importantSettings = @("WEBSITES_PORT", "PORT", "KEY_VAULT_URL", "APPLICATIONINSIGHTS_CONNECTION_STRING", "DOCKER_REGISTRY_SERVER_URL", "DOCKER_REGISTRY_SERVER_USERNAME")

foreach ($setting in $importantSettings) {
    $value = $settings | Where-Object { $_.name -eq $setting }
    if ($value) {
        if ($setting -like "*PASSWORD*" -or $setting -like "*SECRET*") {
            Write-Host "  $setting = ***MASKED***" -ForegroundColor Gray
        } else {
            Write-Host "  $setting = $($value.value)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  $setting = ❌ NOT SET" -ForegroundColor Red
    }
}
Write-Host ""

# 5. Managed Identity確認
Write-Host "[5] Managed Identity確認..." -ForegroundColor Green
$identity = az webapp show --name $WebAppName --resource-group $ResourceGroup --query identity -o json | ConvertFrom-Json
if ($identity.type -eq "SystemAssigned") {
    Write-Host "✅ System-assigned Managed Identity が有効です" -ForegroundColor Green
    Write-Host "  Principal ID: $($identity.principalId)" -ForegroundColor Gray
} else {
    Write-Host "⚠️  WARNING: Managed Identity が設定されていません" -ForegroundColor Yellow
}
Write-Host ""

# 6. ACRアクセス権確認
Write-Host "[6] ACRアクセス権確認..." -ForegroundColor Green
if ($identity.principalId) {
    $acrId = az acr show --name $ACRName --query id -o tsv 2>&1
    if ($LASTEXITCODE -eq 0) {
        $roleAssignment = az role assignment list --assignee $identity.principalId --scope $acrId --query "[?roleDefinitionName=='AcrPull'].roleDefinitionName" -o tsv 2>&1
        if ($roleAssignment -eq "AcrPull") {
            Write-Host "✅ AcrPull ロールが割り当てられています" -ForegroundColor Green
        } else {
            Write-Host "❌ ERROR: AcrPull ロールが割り当てられていません" -ForegroundColor Red
            Write-Host "  実行してください: az role assignment create --assignee $($identity.principalId) --scope $acrId --role AcrPull" -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠️  WARNING: ACR '$ACRName' が見つかりません" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  Managed Identity がないためスキップ" -ForegroundColor Yellow
}
Write-Host ""

# 7. ログ取得
Write-Host "[7] 最新のコンテナログ取得..." -ForegroundColor Green
$logFile = "webapp-diagnosis-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
az webapp log download --name $WebAppName --resource-group $ResourceGroup --log-file $logFile 2>$null
if (Test-Path $logFile) {
    Write-Host "✅ ログファイルをダウンロードしました: $logFile" -ForegroundColor Green
    Write-Host "=== 最新100行 ===" -ForegroundColor Cyan
    Get-Content $logFile -Tail 100
} else {
    Write-Host "⚠️  ログファイルが取得できませんでした" -ForegroundColor Yellow
    Write-Host "リアルタイムログを試行します（Ctrl+Cで終了）..." -ForegroundColor Yellow
    az webapp log tail --name $WebAppName --resource-group $ResourceGroup
}
Write-Host ""

# 8. HTTPヘルスチェック
Write-Host "[8] HTTPヘルスチェック..." -ForegroundColor Green
$url = "https://$WebAppName.azurewebsites.net/health"
Write-Host "URL: $url" -ForegroundColor Gray

try {
    $response = Invoke-WebRequest -Uri $url -Method Get -TimeoutSec 10 -ErrorAction Stop
    Write-Host "✅ Status Code: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Response:" -ForegroundColor Gray
    $response.Content | ConvertFrom-Json | ConvertTo-Json -Depth 5
} catch {
    Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    }
}
Write-Host ""

# 9. 推奨される対処法
Write-Host "=== 推奨される対処法 ===" -ForegroundColor Cyan
Write-Host "1. Managed Identityが有効か確認" -ForegroundColor Yellow
Write-Host "2. AcrPullロールが割り当てられているか確認" -ForegroundColor Yellow
Write-Host "3. WEBSITES_PORT=3000 が設定されているか確認" -ForegroundColor Yellow
Write-Host "4. コンテナログでエラーを確認" -ForegroundColor Yellow
Write-Host "5. Web Appを再起動してみる: az webapp restart --name $WebAppName --resource-group $ResourceGroup" -ForegroundColor Yellow
