# Work Items親子関係設定スクリプト
# Epic → Feature → User Story → Task の階層を構築

param(
    [Parameter(Mandatory=$true)]
    [string]$Organization,
    
    [Parameter(Mandatory=$true)]
    [string]$Project
)

$ErrorActionPreference = "Stop"

# PAT取得
$pat = $env:AZURE_DEVOPS_EXT_PAT
if (-not $pat) {
    Write-Host "❌ エラー: AZURE_DEVOPS_EXT_PAT環境変数が設定されていません" -ForegroundColor Red
    Write-Host "PowerShellプロファイルでPATを設定してください" -ForegroundColor Yellow
    exit 1
}

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))

# ファイル読み込み
$mappingPath = "..\..\WorkItems\workitem-id-mapping.csv"
$originalCsvPath = "..\..\WorkItems\az400-handson-workitems.csv"

if (-not (Test-Path $mappingPath)) {
    Write-Host "❌ エラー: $mappingPath が見つかりません" -ForegroundColor Red
    Write-Host "まず import-workitems.ps1 を実行してください" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n🔗 Work Items 親子関係設定スクリプト" -ForegroundColor Cyan
Write-Host "Organization: $Organization" -ForegroundColor Gray
Write-Host "Project: $Project" -ForegroundColor Gray
Write-Host ""

# IDマッピング読み込み
$mapping = Import-Csv $mappingPath
$originalCsv = Import-Csv $originalCsvPath

# 親子関係の定義（元のCSV IDベース）
# Epic → Features
$relationships = @(
    @{Child="2"; Parent="1"; Desc="Feature 'Day 1' → Epic"}
    @{Child="3"; Parent="1"; Desc="Feature 'Day 2' → Epic"}
    @{Child="4"; Parent="1"; Desc="Feature 'Day 3' → Epic"}
    
    # Feature 2 (Day 1) → User Stories
    @{Child="5"; Parent="2"; Desc="User Story '環境セットアップ' → Feature 'Day 1'"}
    @{Child="9"; Parent="2"; Desc="User Story 'Git/Boards連携' → Feature 'Day 1'"}
    @{Child="15"; Parent="2"; Desc="User Story 'CODEOWNERS/SemVer' → Feature 'Day 1'"}
    @{Child="19"; Parent="2"; Desc="User Story 'Bicepインフラ' → Feature 'Day 1'"}
    
    # Feature 3 (Day 2) → User Stories
    @{Child="24"; Parent="3"; Desc="User Story 'Key Vault IAM' → Feature 'Day 2'"}
    @{Child="29"; Parent="3"; Desc="User Story 'Managed Identity' → Feature 'Day 2'"}
    @{Child="33"; Parent="3"; Desc="User Story 'App Insights統合' → Feature 'Day 2'"}
    @{Child="38"; Parent="3"; Desc="User Story 'KQL実践' → Feature 'Day 2'"}
    
    # Feature 4 (Day 3) → User Stories
    @{Child="43"; Parent="4"; Desc="User Story 'GitHub Actions' → Feature 'Day 3'"}
    @{Child="50"; Parent="4"; Desc="User Story 'Azure Pipelines' → Feature 'Day 3'"}
    @{Child="55"; Parent="4"; Desc="User Story 'CI/CD比較' → Feature 'Day 3'"}
    @{Child="59"; Parent="4"; Desc="User Story 'DevOpsワークフロー' → Feature 'Day 3'"}
    
    # User Story 5 → Tasks
    @{Child="6"; Parent="5"; Desc="Task 'Azure CLI確認' → User Story '環境セットアップ'"}
    @{Child="7"; Parent="5"; Desc="Task 'VS Code' → User Story '環境セットアップ'"}
    @{Child="8"; Parent="5"; Desc="Task 'Azure確認' → User Story '環境セットアップ'"}
    
    # User Story 9 → Tasks
    @{Child="10"; Parent="9"; Desc="Task 'GitHubリポジトリ' → User Story 'Git/Boards'"}
    @{Child="11"; Parent="9"; Desc="Task 'ローカルリポジトリ' → User Story 'Git/Boards'"}
    @{Child="12"; Parent="9"; Desc="Task 'Azure DevOps作成' → User Story 'Git/Boards'"}
    @{Child="13"; Parent="9"; Desc="Task 'GitHub連携' → User Story 'Git/Boards'"}
    @{Child="14"; Parent="9"; Desc="Task 'AB#記法確認' → User Story 'Git/Boards'"}
    
    # User Story 15 → Tasks
    @{Child="16"; Parent="15"; Desc="Task 'CODEOWNERS作成' → User Story 'CODEOWNERS/SemVer'"}
    @{Child="17"; Parent="15"; Desc="Task 'SemVer理解' → User Story 'CODEOWNERS/SemVer'"}
    @{Child="18"; Parent="15"; Desc="Task 'package.json管理' → User Story 'CODEOWNERS/SemVer'"}
    
    # User Story 19 → Tasks
    @{Child="20"; Parent="19"; Desc="Task 'main.bicep' → User Story 'Bicepインフラ'"}
    @{Child="21"; Parent="19"; Desc="Task 'dev.parameters.json' → User Story 'Bicepインフラ'"}
    @{Child="22"; Parent="19"; Desc="Task 'Bicepデプロイ' → User Story 'Bicepインフラ'"}
    @{Child="23"; Parent="19"; Desc="Task 'デプロイ確認' → User Story 'Bicepインフラ'"}
    
    # User Story 24 → Tasks
    @{Child="25"; Parent="24"; Desc="Task 'Key Vault作成' → User Story 'Key Vault IAM'"}
    @{Child="26"; Parent="24"; Desc="Task 'Access Policies' → User Story 'Key Vault IAM'"}
    @{Child="27"; Parent="24"; Desc="Task 'IAM設定' → User Story 'Key Vault IAM'"}
    @{Child="28"; Parent="24"; Desc="Task '動作確認' → User Story 'Key Vault IAM'"}
    
    # User Story 29 → Tasks
    @{Child="30"; Parent="29"; Desc="Task 'Web App作成' → User Story 'Managed Identity'"}
    @{Child="31"; Parent="29"; Desc="Task 'Node.js SDK' → User Story 'Managed Identity'"}
    @{Child="32"; Parent="29"; Desc="Task 'system vs user' → User Story 'Managed Identity'"}
    
    # User Story 33 → Tasks
    @{Child="34"; Parent="33"; Desc="Task 'App Insights作成' → User Story 'App Insights統合'"}
    @{Child="35"; Parent="33"; Desc="Task 'SDK統合' → User Story 'App Insights統合'"}
    @{Child="36"; Parent="33"; Desc="Task 'カスタムメトリクス' → User Story 'App Insights統合'"}
    @{Child="37"; Parent="33"; Desc="Task 'Azure Portal確認' → User Story 'App Insights統合'"}
    
    # User Story 38 → Tasks
    @{Child="39"; Parent="38"; Desc="Task '基本クエリ' → User Story 'KQL実践'"}
    @{Child="40"; Parent="38"; Desc="Task 'bin()集計' → User Story 'KQL実践'"}
    @{Child="41"; Parent="38"; Desc="Task 'extend vs project' → User Story 'KQL実践'"}
    @{Child="42"; Parent="38"; Desc="Task 'percentile()' → User Story 'KQL実践'"}
    
    # User Story 43 → Tasks
    @{Child="44"; Parent="43"; Desc="Task 'Service Principal' → User Story 'GitHub Actions'"}
    @{Child="45"; Parent="43"; Desc="Task 'GitHub Secrets' → User Story 'GitHub Actions'"}
    @{Child="46"; Parent="43"; Desc="Task 'CI Pipeline' → User Story 'GitHub Actions'"}
    @{Child="47"; Parent="43"; Desc="Task 'CD Pipeline' → User Story 'GitHub Actions'"}
    @{Child="48"; Parent="43"; Desc="Task 'Dependabot' → User Story 'GitHub Actions'"}
    @{Child="49"; Parent="43"; Desc="Task 'CodeQL' → User Story 'GitHub Actions'"}
    
    # User Story 50 → Tasks
    @{Child="51"; Parent="50"; Desc="Task 'Service Connection' → User Story 'Azure Pipelines'"}
    @{Child="52"; Parent="50"; Desc="Task 'azure-pipelines.yml' → User Story 'Azure Pipelines'"}
    @{Child="53"; Parent="50"; Desc="Task 'Branch Policy' → User Story 'Azure Pipelines'"}
    @{Child="54"; Parent="50"; Desc="Task 'パイプライン確認' → User Story 'Azure Pipelines'"}
    
    # User Story 55 → Tasks
    @{Child="56"; Parent="55"; Desc="Task '比較表作成' → User Story 'CI/CD比較'"}
    @{Child="57"; Parent="55"; Desc="Task '使い分けガイドライン' → User Story 'CI/CD比較'"}
    @{Child="58"; Parent="55"; Desc="Task '並列ジョブ理解' → User Story 'CI/CD比較'"}
    
    # User Story 59 → Tasks
    @{Child="60"; Parent="59"; Desc="Task 'Work Item作成' → User Story 'DevOpsワークフロー'"}
    @{Child="61"; Parent="59"; Desc="Task 'feature ブランチ' → User Story 'DevOpsワークフロー'"}
    @{Child="62"; Parent="59"; Desc="Task 'AB#記法コミット' → User Story 'DevOpsワークフロー'"}
    @{Child="63"; Parent="59"; Desc="Task 'PR作成' → User Story 'DevOpsワークフロー'"}
    @{Child="64"; Parent="59"; Desc="Task 'CI/CD確認' → User Story 'DevOpsワークフロー'"}
    @{Child="65"; Parent="59"; Desc="Task 'App Insights監視' → User Story 'DevOpsワークフロー'"}
    @{Child="66"; Parent="59"; Desc="Task 'Work Item自動クローズ' → User Story 'DevOpsワークフロー'"}
)

# 親子リンク追加関数
function Add-ParentLink {
    param(
        [string]$ChildId,
        [string]$ParentId,
        [string]$Description
    )
    
    $uri = "https://dev.azure.com/$Organization/$Project/_apis/wit/workitems/$ChildId`?api-version=7.1"
    
    # JSON-Patch形式（ヒアストリングで直接定義）
    $body = @"
[
  {
    "op": "add",
    "path": "/relations/-",
    "value": {
      "rel": "System.LinkTypes.Hierarchy-Reverse",
      "url": "https://dev.azure.com/$Organization/$Project/_apis/wit/workitems/$ParentId"
    }
  }
]
"@
    
    $headers = @{
        Authorization = "Basic $base64AuthInfo"
        "Content-Type" = "application/json-patch+json"
    }
    
    try {
        Invoke-RestMethod -Uri $uri -Method Patch -Headers $headers -Body $body | Out-Null
        Write-Host "✓ " -ForegroundColor Green -NoNewline
        Write-Host "$Description" -ForegroundColor Gray
        return $true
    } catch {
        $errorMsg = $_.Exception.Message
        
        # エラー詳細を取得
        $errorDetail = ""
        if ($_.ErrorDetails.Message) {
            try {
                $errorObj = $_.ErrorDetails.Message | ConvertFrom-Json
                $errorDetail = $errorObj.message
            } catch {
                $errorDetail = $_.ErrorDetails.Message
            }
        }
        
        # 既存リンクエラーの場合
        if ($errorDetail -match "already exists|already exist") {
            Write-Host "⚠ " -ForegroundColor Yellow -NoNewline
            Write-Host "$Description (既存)" -ForegroundColor Gray
            return $true
        } else {
            Write-Host "✗ " -ForegroundColor Red -NoNewline
            Write-Host "$Description" -ForegroundColor Gray
            if ($errorDetail) {
                Write-Host "  └─ $errorDetail" -ForegroundColor Yellow
            } else {
                Write-Host "  └─ $errorMsg" -ForegroundColor Yellow
            }
            return $false
        }
    }
    
    Start-Sleep -Milliseconds 100  # Rate limiting
}

# リンク作成実行
$successCount = 0
$failCount = 0
$totalCount = $relationships.Count

Write-Host "親子関係を設定中... ($totalCount 件)`n" -ForegroundColor Cyan

foreach ($rel in $relationships) {
    $childOriginalId = $rel.Child
    $parentOriginalId = $rel.Parent
    $description = $rel.Desc
    
    # 元のID → Azure DevOps IDに変換
    $childNewId = ($mapping | Where-Object { $_.OriginalID -eq $childOriginalId }).NewID
    $parentNewId = ($mapping | Where-Object { $_.OriginalID -eq $parentOriginalId }).NewID
    
    if (-not $childNewId -or -not $parentNewId) {
        Write-Host "⚠ スキップ: $description (IDが見つかりません: Child=$childOriginalId, Parent=$parentOriginalId)" -ForegroundColor Yellow
        $failCount++
        continue
    }
    
    if (Add-ParentLink -ChildId $childNewId -ParentId $parentNewId -Description $description) {
        $successCount++
    } else {
        $failCount++
    }
}

# 結果サマリー
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "📊 結果サマリー" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan
Write-Host "✓ 成功: $successCount / $totalCount" -ForegroundColor Green
if ($failCount -gt 0) {
    Write-Host "✗ 失敗: $failCount / $totalCount" -ForegroundColor Red
}

Write-Host "`n🔍 確認方法:" -ForegroundColor Cyan
Write-Host "  Backlog view: https://dev.azure.com/$Organization/$Project/_backlogs/backlog" -ForegroundColor Gray
Write-Host "  Epics view:   https://dev.azure.com/$Organization/$Project/_backlogs/backlog/Epics" -ForegroundColor Gray

Write-Host "`n💡 ヒント:" -ForegroundColor Cyan
Write-Host "  - Backlog viewでEpic → Feature → User Story → Taskの階層が表示されます" -ForegroundColor Gray
Write-Host "  - 親Work Itemの進捗は子Taskの完了率から自動計算されます" -ForegroundColor Gray
Write-Host "  - バーンダウンチャートで階層別の進捗を可視化できます" -ForegroundColor Gray

Write-Host "`n✅ 親子関係の設定が完了しました！" -ForegroundColor Green
