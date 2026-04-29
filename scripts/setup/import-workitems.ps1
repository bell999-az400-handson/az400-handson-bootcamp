<#
.SYNOPSIS
    Azure DevOpsにWork ItemsをCSVから一括インポート

.DESCRIPTION
    WorkItems/az400-handson-workitems.csvを読み込んでAzure DevOps REST APIで作成

.PARAMETER Organization
    Azure DevOps組織名（例: bell999）

.PARAMETER Project
    プロジェクト名（例: az400-handson）

.PARAMETER CsvPath
    CSVファイルのパス（デフォルト: WorkItems/az400-handson-workitems.csv）

.EXAMPLE
    .\import-workitems.ps1 -Organization "bell999" -Project "az400-handson"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Organization,
    
    [Parameter(Mandatory=$true)]
    [string]$Project,
    
    [Parameter(Mandatory=$false)]
    [string]$CsvPath = "..\..\WorkItems\az400-handson-workitems.csv"
)

# PAT確認
if (-not $env:AZURE_DEVOPS_EXT_PAT) {
    Write-Error "環境変数 AZURE_DEVOPS_EXT_PAT が設定されていません。"
    Write-Host "以下のコマンドで設定してください："
    Write-Host '$env:AZURE_DEVOPS_EXT_PAT = "your-pat-token"'
    exit 1
}

# CSVファイル確認
if (-not (Test-Path $CsvPath)) {
    Write-Error "CSVファイルが見つかりません: $CsvPath"
    exit 1
}

# CSV読み込み
Write-Host "CSVファイルを読み込み中: $CsvPath" -ForegroundColor Cyan
$workItems = Import-Csv -Path $CsvPath

Write-Host "Work Item数: $($workItems.Count)" -ForegroundColor Green
Write-Host ""

# Azure DevOps REST API設定
$baseUrl = "https://dev.azure.com/$Organization/$Project/_apis"
$apiVersion = "7.1"
$pat = $env:AZURE_DEVOPS_EXT_PAT
$token = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
$headers = @{
    "Authorization" = "Basic $token"
    "Content-Type" = "application/json-patch+json"
}

# Work Item作成関数
function New-WorkItem {
    param(
        [string]$WorkItemType,
        [string]$Title,
        [string]$State,
        [string]$AreaPath,
        [string]$IterationPath,
        [int]$Priority,
        [string]$Description,
        [string]$Tags
    )
    
    # JSON-Patchドキュメント作成
    $body = @()
    
    # Title
    $body += @{
        op = "add"
        path = "/fields/System.Title"
        value = $Title
    }
    
    # State（新規作成時はデフォルト値を使用するためスキップ）
    # Agileプロセスでは作成後に手動で変更する必要があります
    # if ($State) {
    #     $body += @{
    #         op = "add"
    #         path = "/fields/System.State"
    #         value = $State
    #     }
    # }
    
    # Area Path（存在する場合のみ設定、CSVの値は無視してプロジェクトデフォルトを使用）
    # if ($AreaPath) {
    #     $body += @{
    #         op = "add"
    #         path = "/fields/System.AreaPath"
    #         value = "$Project\$AreaPath"
    #     }
    # }
    
    # Iteration Path（存在する場合のみ設定、CSVの値は無視してプロジェクトデフォルトを使用）
    # if ($IterationPath) {
    #     $body += @{
    #         op = "add"
    #         path = "/fields/System.IterationPath"
    #         value = "$Project\$IterationPath"
    #     }
    # }
    
    # Priority
    if ($Priority) {
        $body += @{
            op = "add"
            path = "/fields/Microsoft.VSTS.Common.Priority"
            value = $Priority
        }
    }
    
    # Description
    if ($Description) {
        $body += @{
            op = "add"
            path = "/fields/System.Description"
            value = $Description
        }
    }
    
    # Tags
    if ($Tags) {
        $body += @{
            op = "add"
            path = "/fields/System.Tags"
            value = $Tags
        }
    }
    
    # REST API呼び出し
    $url = "$baseUrl/wit/workitems/`$$WorkItemType`?api-version=$apiVersion"
    
    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body ($body | ConvertTo-Json -Depth 10)
        return $response
    }
    catch {
        Write-Error "Work Item作成失敗: $_"
        Write-Error "URL: $url"
        Write-Error "Body: $($body | ConvertTo-Json -Depth 10)"
        return $null
    }
}

# Work Item作成（型順に処理）
$createdItems = @{}
$workItemTypes = @("Epic", "Feature", "User Story", "Task")

foreach ($type in $workItemTypes) {
    $itemsOfType = $workItems | Where-Object { $_.'Work Item Type' -eq $type }
    
    if ($itemsOfType.Count -eq 0) {
        continue
    }
    
    Write-Host "[$type] を作成中... ($($itemsOfType.Count)個)" -ForegroundColor Yellow
    
    foreach ($item in $itemsOfType) {
        Write-Host "  作成: $($item.Title)" -NoNewline
        
        $result = New-WorkItem `
            -WorkItemType $item.'Work Item Type' `
            -Title $item.Title `
            -State $item.State `
            -AreaPath $item.'Area Path' `
            -IterationPath $item.'Iteration Path' `
            -Priority $item.Priority `
            -Description $item.Description `
            -Tags $item.Tags
        
        if ($result) {
            $createdItems[$item.ID] = $result.id
            Write-Host " ✓ (ID: $($result.id))" -ForegroundColor Green
        }
        else {
            Write-Host " ✗ 失敗" -ForegroundColor Red
        }
        
        # API Rate Limit対策
        Start-Sleep -Milliseconds 500
    }
    
    Write-Host ""
}

# 結果サマリー
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Work Item作成完了" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "作成成功: $($createdItems.Count) / $($workItems.Count)" -ForegroundColor Green
Write-Host ""
Write-Host "Azure DevOps Boardsで確認:" -ForegroundColor Cyan
Write-Host "https://dev.azure.com/$Organization/$Project/_workitems" -ForegroundColor Blue
Write-Host ""

# CSVマッピングファイル作成（親子関係設定用）
$mappingPath = "..\..\WorkItems\workitem-id-mapping.csv"
$mapping = @()
foreach ($key in $createdItems.Keys | Sort-Object) {
    $mapping += [PSCustomObject]@{
        OriginalID = $key
        NewID = $createdItems[$key]
    }
}
$mapping | Export-Csv -Path $mappingPath -NoTypeInformation -Encoding UTF8
Write-Host "IDマッピングファイルを作成しました: $mappingPath" -ForegroundColor Green
Write-Host "このファイルを使用して親子関係を手動で設定できます。" -ForegroundColor Yellow
