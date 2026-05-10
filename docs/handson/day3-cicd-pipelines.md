# Day 3: CI/CD完全マスター（GitHub Actions vs Azure Pipelines）

> **所要時間**: 6-8時間  
> **目標**: GitHub Actions実装、Azure Pipelines実装、両者の比較・使い分け理解

## 🎯 学習目標

- GitHub Actions で完全なCI/CDパイプライン実装
- Azure Pipelines で完全なCI/CDパイプライン実装
- 両者の違いを理解し、使い分けができる
- Branch Policy と CI/CD 統合
- 並列ジョブ理解
- 完全なDevOpsワークフロー実行

---

## ✅ 前提条件

- Day 1, 2 完了
- Azure Container Registry作成済み
- **Web App 3環境（Dev/Staging/Production）デプロイ済み**
  - az400-dev-webapp
  - az400-staging-webapp
  - az400-prod-webapp
  - 各環境でManaged Identity + ACR Pull権限設定済み

---

## 📋 午前セッション（3-4時間）

### ステップ 1: GitHub Actions実装（120分）

#### 1.1 Service Principal作成

> **📝 注意**: この手順は **Day 2で既に実施済み** の場合は省略できます。  
> Day 2で作成したService Principal (`github-actions-az400`) とGitHub Secret (`AZURE_CREDENTIALS`) をそのまま使用してください。

```powershell
# 1. サブスクリプションIDを取得
$SUBSCRIPTION_ID = az account show --query id -o tsv

# 2. サービスプリンシパルを作成してクリップボードにコピー（推奨）
az ad sp create-for-rbac `
  --name "github-actions-az400" `
  --role contributor `
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-az400-handson" `
  --sdk-auth | Set-Clipboard

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Azure認証情報をクリップボードにコピーしました" -ForegroundColor Green
    Write-Host "⚠️ この情報は機密です。GitHub Secretsに設定したら、クリップボードをクリアしてください" -ForegroundColor Yellow
} else {
    Write-Host "❌ Service Principal作成に失敗しました（終了コード: $LASTEXITCODE）" -ForegroundColor Red
}

# 3. 作成されたService Principalを確認
Write-Host "`n📋 Service Principal一覧:" -ForegroundColor Cyan
az ad sp list --filter "displayName eq 'github-actions-az400'" --query "[].{Name:displayName, AppId:appId, CreatedDate:createdDateTime}" -o table

# 4. クリップボードの内容を確認（任意）
# Get-Clipboard | ConvertFrom-Json | ConvertTo-Json -Depth 5

# 5. クリップボードから直接GitHub Secretsに設定（次のステップで使用）
```

出力例:
```json
{
  "clientId": "...",
  "clientSecret": "...",
  "subscriptionId": "...",
  "tenantId": "...",
  "..."
}
```

#### 1.2 GitHub Secrets設定

> **📝 注意**: Day 2で既に `AZURE_CREDENTIALS` と `ACR_LOGIN_SERVER` を設定済みの場合、この手順は不要です。

GitHub > Settings > Secrets and variables > Actions に以下を設定:

1. **AZURE_CREDENTIALS**: Service Principalの認証情報（上記JSONファイル全体）
2. **ACR_LOGIN_SERVER**: Azure Container RegistryのログインサーバーURL

```powershell
# ACR_LOGIN_SERVER の値を取得
az acr show --name az400acr --resource-group rg-az400-handson --query loginServer -o tsv
# 出力例: az400acr.azurecr.io
```

**GitHub Secretsへの設定手順：**

1. GitHubリポジトリで **Settings** → **Secrets and variables** → **Actions** をクリック
2. **New repository secret** をクリック
3. 以下のSecretを追加:
   - Name: `ACR_LOGIN_SERVER`
   - Value: `az400acr.azurecr.io` (上記コマンドの出力)

**備考**: 
- ACRへのログインは `az acr login` を使用するため、ACR個別の認証情報（ACR_USERNAME/PASSWORD）は不要です
- `AZURE_CREDENTIALS` のみでACR + Web Appの両方にアクセス可能です
- `ACR_LOGIN_SERVER` はCD Pipelineでコンテナイメージのフルパス指定に使用されます

#### 1.3 CI Pipeline作成

**CI Pipelineの目的**: mainまたはdevelopブランチへのpush、およびmainへのPR時に自動実行され、コード品質の確保とDockerイメージの作成を行います。

**.github/workflows/ci-github-actions.yml**:

```yaml
name: CI - GitHub Actions

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

env:
  NODE_VERSION: '18'
  WORKING_DIRECTORY: './src/webapp'

jobs:
  # ジョブ1: ビルドとテスト
  # 目的: Node.jsアプリケーションの依存関係インストール、Lint、テスト実行、カバレッジ収集
  build-and-test:
    name: Build and Test
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v6
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          cache-dependency-path: ${{ env.WORKING_DIRECTORY }}/package-lock.json
      
      - name: Install dependencies
        run: npm ci
        working-directory: ${{ env.WORKING_DIRECTORY }}
      
      - name: Run linter
        run: npm run lint || echo "No lint script defined"
        working-directory: ${{ env.WORKING_DIRECTORY }}
        continue-on-error: true
      
      - name: Run tests
        run: npm test
        working-directory: ${{ env.WORKING_DIRECTORY }}
      
      - name: Upload coverage reports
        uses: codecov/codecov-action@v6
        with:
          directory: ${{ env.WORKING_DIRECTORY }}/coverage
          fail_ci_if_error: false
  
  # ジョブ2: Dockerイメージビルドとセキュリティスキャン
  # 目的: ACRへのDockerイメージpush、Trivyによる脆弱性スキャン、GitHub Securityへの結果アップロード
  # 実行条件: build-and-testジョブが成功 かつ pushイベント（PR時は実行しない）
  docker-build:
    name: Build and Push Docker Image
    runs-on: ubuntu-latest
    needs: build-and-test
    if: github.event_name == 'push'
    
    permissions:
      contents: read
      security-events: write
      actions: read
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Azure Login
        uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Login to Azure Container Registry
        run: |
          az acr login --name az400acr
      
      - name: Build and push Docker image
        run: |
          docker build -t az400acr.azurecr.io/az400webapp:${{ github.sha }} \
                       -t az400acr.azurecr.io/az400webapp:latest \
                       ${{ env.WORKING_DIRECTORY }}
          docker push az400acr.azurecr.io/az400webapp:${{ github.sha }}
          docker push az400acr.azurecr.io/az400webapp:latest
      
      - name: Image scan (Trivy)
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: az400acr.azurecr.io/az400webapp:${{ github.sha }}
          format: 'sarif'
          output: 'trivy-results.sarif'
        continue-on-error: true
      
      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v4
        if: always() && github.event_name == 'push'
        with:
          sarif_file: 'trivy-results.sarif'
        continue-on-error: true
```

#### 1.4 CD Pipeline作成

**CD Pipelineの目的**: CI Pipelineが成功後、Dev → Staging → Productionの順に段階的デプロイを実行します。各環境でヘルスチェックと検証を行い、問題があれば次の環境へ進みません。

**具体的な実装手順：**

**手順0: Azure Web App 3環境の作成（未作成の場合）**

> **📝 重要**: CD Pipelineは3環境（Dev/Staging/Production）への段階的デプロイを実行します。Day 2でDev環境のみ作成した場合、StagingとProductionを追加で作成してください。

```powershell
# 1. 現在のWeb App一覧を確認
az webapp list --resource-group rg-az400-handson --query "[].{Name:name, State:state}" -o table

# 2. Staging環境を作成（存在しない場合）
if (-not (az webapp show --name az400-staging-webapp --resource-group rg-az400-handson 2>$null)) {
    Write-Host "📦 Staging環境を作成中..." -ForegroundColor Cyan
    
    # 既存のDev環境のApp Service Planを再利用（追加コストなし）
    az webapp create `
      --name az400-staging-webapp `
      --resource-group rg-az400-handson `
      --plan az400-dev-asp `
      --deployment-container-image-name mcr.microsoft.com/appsvc/staticsite:latest
    
    # Managed Identityを有効化
    $stagingPrincipalId = az webapp identity assign `
      --name az400-staging-webapp `
      --resource-group rg-az400-handson `
      --query principalId -o tsv
    
    # ACR Pull権限を付与
    $acrId = az acr show --name az400acr --resource-group rg-az400-handson --query id -o tsv
    az role assignment create `
      --assignee $stagingPrincipalId `
      --role AcrPull `
      --scope $acrId
    
    # ACR Managed Identity認証を有効化
    az webapp config set `
      --name az400-staging-webapp `
      --resource-group rg-az400-handson `
      --generic-configurations '{"acrUseManagedIdentityCreds": true}'
    
    # Application Insights接続文字列を取得（拡張機能インストール確認で"Y"を入力）
    $appInsightsConnStr = az monitor app-insights component show `
      --app az400-dev-ai `
      --resource-group rg-az400-handson `
      --query connectionString -o tsv
    
    # 環境変数を設定
    az webapp config appsettings set `
      --name az400-staging-webapp `
      --resource-group rg-az400-handson `
      --settings `
        APPLICATIONINSIGHTS_CONNECTION_STRING="$appInsightsConnStr" `
        DOCKER_ENABLE_CI=true `
        WEBSITES_ENABLE_APP_SERVICE_STORAGE=false `
        PORT=3000
    
    Write-Host "✅ Staging環境作成完了" -ForegroundColor Green
} else {
    Write-Host "✅ Staging環境は既に存在します" -ForegroundColor Green
}

# 3. Production環境を作成（存在しない場合）
if (-not (az webapp show --name az400-prod-webapp --resource-group rg-az400-handson 2>$null)) {
    Write-Host "📦 Production環境を作成中..." -ForegroundColor Cyan
    
    # 既存のDev環境のApp Service Planを再利用（追加コストなし）
    az webapp create `
      --name az400-prod-webapp `
      --resource-group rg-az400-handson `
      --plan az400-dev-asp `
      --deployment-container-image-name mcr.microsoft.com/appsvc/staticsite:latest
    
    # Managed Identityを有効化
    $prodPrincipalId = az webapp identity assign `
      --name az400-prod-webapp `
      --resource-group rg-az400-handson `
      --query principalId -o tsv
    
    # ACR Pull権限を付与
    $acrId = az acr show --name az400acr --resource-group rg-az400-handson --query id -o tsv
    az role assignment create `
      --assignee $prodPrincipalId `
      --role AcrPull `
      --scope $acrId
    
    # ACR Managed Identity認証を有効化
    az webapp config set `
      --name az400-prod-webapp `
      --resource-group rg-az400-handson `
      --generic-configurations '{"acrUseManagedIdentityCreds": true}'
    
    # Application Insights接続文字列を取得
    $appInsightsConnStr = az monitor app-insights component show `
      --app az400-dev-ai `
      --resource-group rg-az400-handson `
      --query connectionString -o tsv
    
    # 環境変数を設定
    az webapp config appsettings set `
      --name az400-prod-webapp `
      --resource-group rg-az400-handson `
      --settings `
        APPLICATIONINSIGHTS_CONNECTION_STRING="$appInsightsConnStr" `
        DOCKER_ENABLE_CI=true `
        WEBSITES_ENABLE_APP_SERVICE_STORAGE=false `
        PORT=3000
    
    Write-Host "✅ Production環境作成完了" -ForegroundColor Green
} else {
    Write-Host "✅ Production環境は既に存在します" -ForegroundColor Green
}

# 4. 全環境の状態を確認
Write-Host "`n📋 Web App環境一覧:" -ForegroundColor Cyan
az webapp list --resource-group rg-az400-handson --query "[].{Name:name, State:state}" -o table

Write-Host "`n💡 ポイント:" -ForegroundColor Yellow
Write-Host "  - 全環境が同一のB1 App Service Plan（az400-dev-asp）を使用" -ForegroundColor White
Write-Host "  - 追加のWeb Appを作成してもプラン料金は変わりません（コスト最適化）" -ForegroundColor White
Write-Host "  - 各環境にManaged Identity + ACR Pull権限が設定済み" -ForegroundColor White
```

**トラブルシューティング：**

- **Q: Application Insights拡張機能インストール確認が表示される**  
  A: 初回実行時に "The command requires the extension application-insights. Do you want to install it now? (Y/n):" と表示されます。`Y` を入力してインストールしてください。

- **Q: Storage Account名が長すぎるエラーが出る**  
  A: Bicepで環境を作成する場合、Storage Account名は24文字以下にしてください（例: `az400stagingsa` → `az400stgsa`）。ただし、上記の手順ではWeb Appのみ作成するため、このエラーは発生しません。

- **Q: Free Tier (F1) のクォータエラーが出る**  
  A: Free Tierは1サブスクリプションあたり1つまでです。上記の手順では既存のB1プランを再利用するため、このエラーは発生しません。

---

**手順1: ワークフローファイルの作成**

```powershell
# 1. ワークフローディレクトリが存在することを確認
if (-not (Test-Path ".github/workflows")) {
    New-Item -Path ".github/workflows" -ItemType Directory -Force
    Write-Host "✅ .github/workflows ディレクトリを作成しました" -ForegroundColor Green
}

# 2. CD Pipelineファイルを作成
New-Item -Path ".github/workflows/cd-github-actions.yml" -ItemType File -Force
Write-Host "✅ cd-github-actions.yml を作成しました" -ForegroundColor Green
```

**手順2: GitHub Environmentsの設定**

CD Pipelineは3つの環境（development/staging/production）を使用するため、GitHub上で事前設定が必要です。

```powershell
# ブラウザでGitHubリポジトリを開く
start "https://github.com/YOUR_USERNAME/az400-handson-bootcamp/settings/environments"
```

**GitHub Web UIでの操作：**

1. **Settings** → **Environments** → **New environment** をクリック

2. **Development環境**:
   - Name: `development`
   - Required reviewers: 設定不要（自動デプロイ）

3. **Staging環境**:
   - Name: `staging`
   - Required reviewers: 任意

4. **Production環境**:
   - Name: `production`
   - ✅ **Required reviewers**: 1人以上選択（本番デプロイ前の承認）
   - Wait timer: 0分（即座）または5分など

**手順3: YAMLファイルに内容を記述**

以下のYAMLコードを `.github/workflows/cd-github-actions.yml` に記述します。

**.github/workflows/cd-github-actions.yml**:

```yaml
name: CD - GitHub Actions

on:
  workflow_run:
    workflows: ["CI - GitHub Actions"]
    types:
      - completed
    branches: [main]

env:
  AZURE_WEBAPP_NAME: 'az400-dev-webapp'
  RESOURCE_GROUP: 'rg-az400-handson'

jobs:
  # ジョブ1: 開発環境へのデプロイ
  # 目的: 最新のDockerイメージをDev環境にデプロイし、詳細な診断とヘルスチェックを実行
  # 特徴: Web App存在確認、デプロイ後の設定確認、リトライ機能付きSmoke test、失敗時の詳細ログ収集
  deploy-dev:
    name: Deploy to Development
    runs-on: ubuntu-latest
    if: github.event.workflow_run.conclusion == 'success'
    environment:
      name: development
      url: https://${{ env.AZURE_WEBAPP_NAME }}.azurewebsites.net
    
    steps:
      - name: Login to Azure
        uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Check Web App existence
        run: |
          echo "🔍 Verifying Web App exists..."
          if ! az webapp show --name ${{ env.AZURE_WEBAPP_NAME }} --resource-group ${{ env.RESOURCE_GROUP }} &>/dev/null; then
            echo "❌ ERROR: Web App '${{ env.AZURE_WEBAPP_NAME }}' not found in resource group '${{ env.RESOURCE_GROUP }}'"
            echo "Available web apps in resource group:"
            az webapp list --resource-group ${{ env.RESOURCE_GROUP }} --query "[].{Name:name, State:state}" -o table
            exit 1
          fi
          echo "✅ Web App exists"
      
      - name: Deploy to Azure Web App
        uses: azure/webapps-deploy@v3
        with:
          app-name: ${{ env.AZURE_WEBAPP_NAME }}
          images: az400acr.azurecr.io/az400webapp:${{ github.sha }}
      
      - name: Verify deployment and diagnose issues
        run: |
          echo "📋 Checking deployment status..."
          STATE=$(az webapp show --name ${{ env.AZURE_WEBAPP_NAME }} --resource-group ${{ env.RESOURCE_GROUP }} --query state -o tsv)
          echo "App state: $STATE"
          
          echo ""
          echo "🐳 Checking container configuration..."
          az webapp config container show --name ${{ env.AZURE_WEBAPP_NAME }} --resource-group ${{ env.RESOURCE_GROUP }}
          
          echo ""
          echo "📝 Checking application settings..."
          az webapp config appsettings list --name ${{ env.AZURE_WEBAPP_NAME }} --resource-group ${{ env.RESOURCE_GROUP }} --query "[?name=='WEBSITES_PORT' || name=='PORT' || name=='KEY_VAULT_URL' || name=='APPLICATIONINSIGHTS_CONNECTION_STRING'].{Name:name, Value:value}" -o table
          
          echo ""
          echo "📊 Fetching container logs (last 100 lines)..."
          az webapp log download --name ${{ env.AZURE_WEBAPP_NAME }} --resource-group ${{ env.RESOURCE_GROUP }} --log-file deployment.log 2>/dev/null || true
          if [ -f deployment.log ]; then
            echo "=== Recent logs ==="
            tail -n 100 deployment.log
          else
            echo "⚠️  Log file not available yet"
          fi
          
          echo ""
          echo "🔧 Checking runtime status..."
          az webapp show --name ${{ env.AZURE_WEBAPP_NAME }} --resource-group ${{ env.RESOURCE_GROUP }} --query "{State:state, AvailabilityState:availabilityState, UsageState:usageState, OutboundIpAddresses:outboundIpAddresses}" -o json
      
      - name: Smoke test
        run: |
          echo "Waiting for container to start..."
          # 最大2分間、10秒ごとにリトライ
          for i in {1..12}; do
            echo "Health check attempt $i/12..."
            
            # まずHTTPステータスコードを確認
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 https://${{ env.AZURE_WEBAPP_NAME }}.azurewebsites.net/health || echo "000")
            echo "HTTP Status: $HTTP_CODE"
            
            if [ "$HTTP_CODE" = "200" ]; then
              echo "✓ Health check passed"
              curl -s https://${{ env.AZURE_WEBAPP_NAME }}.azurewebsites.net/health | jq . || true
              exit 0
            elif [ "$HTTP_CODE" = "503" ]; then
              echo "⚠️  Service Unavailable (503) - Container may still be starting..."
            elif [ "$HTTP_CODE" = "000" ]; then
              echo "❌ Connection failed - Timeout or network error"
            else
              echo "⚠️  Unexpected status code: $HTTP_CODE"
            fi
            
            if [ $i -lt 12 ]; then
              echo "Waiting 10 seconds before retry..."
              sleep 10
            fi
          done
          
          echo ""
          echo "✗ Health check failed after 12 attempts (2 minutes)"
          echo "=== Final diagnostics ==="
          echo "Attempting to access root URL..."
          curl -v https://${{ env.AZURE_WEBAPP_NAME }}.azurewebsites.net/ 2>&1 | head -n 50
          exit 1
      
      - name: Show logs on failure
        if: failure()
        run: |
          echo "=== Deployment failed - collecting diagnostic information ==="
          az webapp log download --name ${{ env.AZURE_WEBAPP_NAME }} --resource-group ${{ env.RESOURCE_GROUP }} --log-file failure.log 2>/dev/null || true
          if [ -f failure.log ]; then
            echo "=== Full log file ==="
            cat failure.log
          fi
          
          echo ""
          echo "=== Container settings ==="
          az webapp config show --name ${{ env.AZURE_WEBAPP_NAME }} --resource-group ${{ env.RESOURCE_GROUP }}
      
  # ジョブ2: ステージング環境へのデプロイ
  # 目的: Dev環境での検証が成功後、Staging環境にデプロイし統合テストを実行
  # 実行条件: deploy-devジョブが成功
      - name: Notification
        if: always()
        run: |
          echo "Deployment to Development: ${{ job.status }}"
  
  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: deploy-dev
    environment:
      name: staging
      url: https://az400-staging-webapp.azurewebsites.net
    
    steps:
      - name: Login to Azure
        uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Deploy to Staging Web App
        uses: azure/webapps-deploy@v3
        with:
  # ジョブ3: 本番環境へのデプロイ
  # 目的: Staging環境での検証が成功後、本番環境にデプロイし通知を送信
  # 実行条件: deploy-stagingジョブが成功
  # セキュリティ: GitHub Environmentsの承認機能により、手動承認後にデプロイ可能
          app-name: 'az400-staging-webapp'
          images: az400acr.azurecr.io/az400webapp:${{ github.sha }}
      
      - name: Run integration tests
        run: |
          echo "Running integration tests..."
          # 実際のテストスクリプト
  
  deploy-prod:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: deploy-staging
    environment:
      name: production
      url: https://az400-prod-webapp.azurewebsites.net
    
    steps:
      - name: Login to Azure
        uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Deploy to Production Web App
        uses: azure/webapps-deploy@v3
        with:
          app-name: 'az400-prod-webapp'
          images: az400acr.azurecr.io/az400webapp:${{ github.sha }}
      
      - name: Notify deployment
        run: |
          echo "Production deployment completed!"
```

**手順4: コミット＆プッシュ**

```powershell
# 1. ファイルをステージング
git add .github/workflows/cd-github-actions.yml

# 2. コミット
git commit -m "feat: CD Pipeline追加（Dev/Staging/Prod段階的デプロイ）"

# 3. プッシュ
git push origin main
```

**手順5: 動作確認**

```powershell
# GitHub Actionsページを開く
start "https://github.com/YOUR_USERNAME/az400-handson-bootcamp/actions"
```

**確認ポイント：**
1. ✅ CI Pipeline（ci-github-actions.yml）が先に実行される
2. ✅ CI成功後、CD Pipeline（cd-github-actions.yml）が自動的にトリガーされる
3. ✅ Deploy to Development → Deploy to Staging → Deploy to Production の順に実行
4. ✅ Production環境で承認待ち状態になる（Required reviewersを設定した場合）

**手順6: Production承認（Required reviewers設定時）**

1. GitHub Actions実行画面で「**Review deployments**」ボタンをクリック
2. ✅ production環境をチェック
3. **Approve and deploy** をクリック
4. Productionデプロイが開始される

**トラブルシューティング：**

**Q: "Environment not found" エラーが出る**
- A: GitHub SettingsでEnvironments（development/staging/production）を作成してください

**Q: CD Pipelineがトリガーされない**
- A: `workflow_run.conclusion == 'success'` の条件を確認。CI Pipelineが成功している必要があります

**Q: Web App名が違う**
- A: YAMLファイルの `AZURE_WEBAPP_NAME` を実際のWeb App名に変更してください

```powershell
# 実際のリソース名を確認
az webapp list -g rg-az400-handson --query "[].name" -o table
```

**Q: "ResourceNotFound: Web App 'az400-staging-webapp' not found" または "az400-prod-webapp not found" エラーが出る**
- A: CD Pipelineは3環境（Dev/Staging/Production）への段階的デプロイを実行します。**手順0: Azure Web App 3環境の作成**を実施して、全環境を作成してください
- 確認コマンド:
```powershell
# 存在するWeb Appを確認
az webapp list --resource-group rg-az400-handson --query "[].{Name:name, State:state}" -o table

# 期待される出力: az400-dev-webapp, az400-staging-webapp, az400-prod-webapp の3つ
```

**Q: "Application Error" が表示される**
- A: Free (F1) App Service Planの制限超過が原因です。Basic (B1) へアップグレードが必要です

```powershell
# App Service PlanのSKU確認
az appservice plan show -n az400-dev-asp -g rg-az400-handson --query "{sku:sku.name,tier:sku.tier}" -o table

# Basic (B1) へアップグレード（推奨）
az appservice plan update -n az400-dev-asp -g rg-az400-handson --sku B1

# Web App再起動
az webapp restart -n az400-dev-webapp -g rg-az400-handson
```

**理由**: Free (F1) tierは以下の制限があり、コンテナワークロードには不適切です：
- CPU時間: 60分/日のみ
- Always On: 利用不可
- 制限超過で自動停止 → Application Error

**Q: Azure Diagnoseで "Health Check not configured" 警告が出る**
- A: Health Check機能を有効化してください

```powershell
# Health Checkパスを設定（/healthエンドポイントを使用）
az webapp update -n az400-dev-webapp -g rg-az400-handson --set siteConfig.healthCheckPath="/health"

# 設定確認
az webapp config show -n az400-dev-webapp -g rg-az400-handson --query "healthCheckPath" -o tsv
```

**効果**: 
- 1分ごとに全インスタンスの `/health` エンドポイントをチェック
- 不健全なインスタンスを自動的にローテーションから除外
- 本番環境では必須の設定

**Q: "Single instance warning" が出る**
- A: 学習環境では1インスタンスで十分です。本番環境では2インスタンス以上を推奨

```powershell
# 手動スケール（2インスタンス）
az appservice plan update -n az400-dev-asp -g rg-az400-handson --set sku.capacity=2

# 自動スケール設定（CPU 70%以上で自動増加）
az monitor autoscale create `
  --resource-group rg-az400-handson `
  --resource az400-dev-asp `
  --resource-type Microsoft.Web/serverfarms `
  --name autoscale-rule `
  --min-count 1 `
  --max-count 3 `
  --count 1

az monitor autoscale rule create `
  --resource-group rg-az400-handson `
  --autoscale-name autoscale-rule `
  --condition "Percentage CPU > 70 avg 5m" `
  --scale out 1
```

**💡 AZ-400試験対策ポイント**:
- ✅ **App Service Plan SKU選択**: Free/Basic/Standard/Premiumの違いと使い分け
- ✅ **Health Check**: 本番環境では必須、インスタンスの健全性監視
- ✅ **高可用性**: 複数インスタンス + 自動スケールでダウンタイム削減
- ✅ **コスト最適化**: 学習環境はBasic B1 (1インスタンス)、本番はStandard以上 (2+インスタンス)

**Q: デプロイ後に HTTP 503 が続き、コンテナが起動しない**
- A: `linuxFxVersion`のイメージパスにレジストリURLが含まれているか確認

**症状**: 
- CD Pipeline成功後もHTTP 503エラーが継続
- Azure Portal → Deployment Center で "Failed to pull image: docker.io/library/az400webapp" エラー
- 正しいACRからではなく、Docker Hubから取得しようとしている

**原因診断**:
```powershell
# 現在の設定を確認
az webapp config show -n az400-dev-webapp -g rg-az400-handson --query "linuxFxVersion" -o tsv

# ❌ 間違った形式（レジストリURLが欠落）
# DOCKER|/az400webapp:bdae8a7...

# ✅ 正しい形式
# DOCKER|az400acr.azurecr.io/az400webapp:bdae8a7...
```

**解決策1: CI/CD Pipelineを再実行**（推奨）
```powershell
# GitHubで以下を実行:
# 1. Actions タブ → "CI - GitHub Actions" → 最新run → "Re-run all jobs"
# 2. CI成功後、CD Pipelineが自動実行
# 3. 修正版のCD PipelineがlinuxFxVersionを正しく設定
```

**解決策2: 手動でイメージパスを修正**
```powershell
# PowerShellではパイプ文字(|)が問題になるため、bashを使用
bash -c "az webapp config set --name az400-dev-webapp --resource-group rg-az400-handson --linux-fx-version 'DOCKER|az400acr.azurecr.io/az400webapp:latest'"

# Web Appを再起動
az webapp restart -n az400-dev-webapp -g rg-az400-handson

# 60秒待機してからヘルスチェック
Start-Sleep -Seconds 60
curl https://az400-dev-webapp.azurewebsites.net/health
```

**解決策3: Azure Portal UIで修正**
1. Azure Portal → App Services → az400-dev-webapp
2. Deployment Center → Registry settings
3. Image and tag: `az400acr.azurecr.io/az400webapp:latest`
4. Save → Web Appが自動的に再起動

**根本原因**: 
- `azure/webapps-deploy@v3`の`images`パラメータだけでは、`linuxFxVersion`が正しく更新されないことがある
- CD Pipelineで`az webapp config set --linux-fx-version`を明示的に実行する必要がある

**修正版CD Pipeline** (2024年5月対応済み):
```yaml
- name: Set container image explicitly
  run: |
    IMAGE_PATH="${{ secrets.ACR_LOGIN_SERVER }}/az400webapp:${{ github.sha }}"
    az webapp config set \
      --name ${{ env.AZURE_WEBAPP_NAME }} \
      --resource-group ${{ env.RESOURCE_GROUP }} \
      --linux-fx-version "DOCKER|$IMAGE_PATH"

- name: Deploy to Azure Web App
  uses: azure/webapps-deploy@v3
  with:
    images: ${{ secrets.ACR_LOGIN_SERVER }}/az400webapp:${{ github.sha }}
```

---

### ステップ 2: セキュリティスキャン（60分）

#### 2.1 Dependabot設定

**.github/dependabot.yml**:

```yaml
version: 2
updates:
  # npm dependencies
  - package-ecosystem: "npm"
    directory: "/src/webapp"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
    labels:
      - "dependencies"
      - "security"
  
  # Docker dependencies
  - package-ecosystem: "docker"
    directory: "/src/webapp"
    schedule:
      interval: "weekly"
  
  # GitHub Actions dependencies
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

#### 2.2 CodeQL設定

**目的**: GitHubの静的解析ツールCodeQLを使用して、セキュリティ脆弱性とコード品質の問題を自動検出します。push/PR時および毎週月曜の定期スキャンで実行されます。

**.github/workflows/security-scan.yml**:

```yaml
name: Security Scan

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 0 * * 1'  # 毎週月曜日

jobs:
  # CodeQLによる静的セキュリティ分析
  # 目的: JavaScriptコードの脆弱性、バグ、コード品質問題を検出しGitHub Securityに結果を送信
  # 実行頻度: push/PR時 + 毎週月曜日の定期スキャン
  codeql:
    name: CodeQL Analysis
    runs-on: ubuntu-latest
    permissions:
      security-events: write
      actions: read
      contents: read
    
    steps:
      - name: Checkout repository
        uses: actions/checkout@v3
      
      - name: Initialize CodeQL
        uses: github/codeql-action/init@v2
        with:
          languages: javascript
      
      - name: Autobuild
        uses: github/codeql-action/autobuild@v2
      
      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v2
```

#### 2.3 セキュリティ脆弱性の対処

**目的**: DependabotやGitHub Securityで検出された依存関係の脆弱性を修正します。

**手順1: 脆弱性の確認**

```powershell
# 1. Webアプリケーションディレクトリに移動
cd src/webapp

# 2. npm auditで脆弱性を確認
npm audit

# 3. 詳細表示
npm audit --json
```

**手順2: GitHub Securityで確認**

```powershell
# GitHub Securityページを開く
start "https://github.com/YOUR_USERNAME/az400-handson-bootcamp/security/dependabot"
```

**よくある脆弱性とその対処：**

1. **brace-expansion: Denial of Service**
   - 影響: ブレース展開処理でのDoS攻撃
   - 対処: `npm audit fix`で自動更新

2. **ip-address: XSS vulnerability**
   - 影響: IPv6アドレス表示メソッドでのXSS
   - 対処: パッケージバージョンアップ

3. **picomatch: Data integrity & ReDoS**
   - 影響: 正規表現DoSとデータ整合性の問題
   - 対処: 最新バージョンへ更新

**手順3: 自動修正の実行**

```powershell
# 1. 自動修正を試行（破壊的でない変更のみ）
npm audit fix

# 2. 修正結果を確認
npm audit

# 3. まだ脆弱性が残っている場合、強制修正を検討
# ⚠️ 警告: これは破壊的変更を含む可能性があります
npm audit fix --force

# 4. テストを実行して動作確認
npm test
```

**手順4: 手動修正（自動修正できない場合）**

```powershell
# 1. 特定パッケージを最新バージョンに更新
npm update brace-expansion
npm update ip-address
npm update picomatch

# 2. または、特定バージョンをインストール
npm install brace-expansion@latest
npm install ip-address@latest
npm install picomatch@latest

# 3. package-lock.jsonを再生成
npm install

# 4. テストを実行
npm test
```

**手順5: 変更のコミット**

```powershell
# 1. 変更ファイルを確認
git status

# 2. package.jsonとpackage-lock.jsonをステージング
git add src/webapp/package.json src/webapp/package-lock.json

# 3. セキュリティ修正コミット
git commit -m "fix: セキュリティ脆弱性の修正（brace-expansion, ip-address, picomatch）"

# 4. プッシュ
git push origin main
```

**手順6: Dependabot PRの対処**

DependabotがPRを自動作成した場合：

1. **GitHub Web UIでPRを確認**
   ```powershell
   start "https://github.com/YOUR_USERNAME/az400-handson-bootcamp/pulls"
   ```

2. **PRの内容を確認**:
   - 変更内容（package.json, package-lock.json）
   - CI/CDが成功しているか
   - 互換性情報

3. **マージ**:
   - ✅ CI/CDが成功 → **Merge pull request**
   - ❌ CI/CDが失敗 → ログ確認、手動修正

**ベストプラクティス：**

✅ **定期的なチェック**: 毎週1回 `npm audit` を実行  
✅ **Dependabot有効化**: 自動PR作成で脆弱性を早期発見  
✅ **テストの徹底**: 修正後は必ずテスト実行  
✅ **段階的適用**: Dev → Staging → Prod の順に修正を展開  
✅ **ロールバック準備**: 問題が発生した場合のロールバック手順を用意  

**AZ-400試験のポイント：**

- Q: "依存関係の脆弱性を定期的にチェックする方法は？"
- A: Dependabot設定 + `npm audit` の定期実行

- Q: "本番環境への影響を最小限にするには？"
- A: Dev/Stagingで検証後、Production適用

---

## 📋 午後セッション（3-4時間）

### ステップ 3: Azure Pipelines実装（120分）

#### 3.1 Azure Pipelines YAML作成

**目的**: Azure DevOpsのネイティブCI/CDツールであるAzure Pipelinesを使用して、GitHub Actionsと同等の機能を実装します。Multi-stage Pipelineによる段階的デプロイと、Branch Policyによる品質ゲート制御が特徴です。

**.azure/pipelines/azure-pipelines.yml**:

```yaml
trigger:
  branches:
    include:
      - main
      - develop
  paths:
    exclude:
      - docs/*
      - README.md

pr:
  branches:
    include:
      - main

variables:
  nodeVersion: '18.x'
  workingDirectory: 'src/webapp'
  acrName: 'az400acr'
  azureSubscription: 'AzureServiceConnection'

stages:
  # ステージ1: ビルドとテスト
  # 目的: アプリケーションのビルド、テスト実行、Dockerイメージ作成をパラレルに実行
  - stage: Build
    displayName: 'Build and Test'
    jobs:
      # ジョブ1: アプリケーションビルドとテスト
      # 目的: Node.js依存関係インストール、テスト実行、テスト結果の発行
      - job: BuildJob
        displayName: 'Build Application'
        pool:
          vmImage: 'ubuntu-latest'
        
        steps:
          - task: NodeTool@0
            displayName: 'Install Node.js'
            inputs:
              versionSpec: $(nodeVersion)
          
          - script: npm ci
            displayName: 'Install dependencies'
            workingDirectory: $(workingDirectory)
          
          - script: npm test
            displayName: 'Run tests'
            workingDirectory: $(workingDirectory)
          
          - task: PublishTestResults@2
            displayName: 'Publish test results'
            condition: succeededOrFailed()
            inputs:
              testResultsFormat: 'JUnit'
              testResultsFiles: '**/test-results.xml'
              failTaskOnFailedTests: true
      
      # ジョブ2: Dockerイメージビルド
      # 目的: BuildJobの成功後、DockerイメージをビルドしてACRにpush
      # 依存関係: BuildJobの成功が必須
      - job: DockerBuild
        displayName: 'Build Docker Image'
        dependsOn: BuildJob
        pool:
          vmImage: 'ubuntu-latest'
        
        steps:
          - task: Docker@2
            displayName: 'Build and Push Docker Image'
            inputs:
              containerRegistry: 'ACRServiceConnection'
              repository: 'az400webapp'
              command: 'buildAndPush'
              Dockerfile: '$(workingDirectory)/Dockerfile'
              tags: |
                $(Build.BuildId)
                latest

  # ステージ2: 開発環境へのデプロイ
  # 目的: Buildステージ成功後、mainブランチのみDev環境にデプロイ
  # 実行条件: Buildステージが成功 AND mainブランチ
  - stage: DeployDev
    displayName: 'Deploy to Development'
    dependsOn: Build
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      # デプロイメントジョブ: Development環境
      # 目的: ACRのDockerイメージをAzure Web Appにデプロイ
      # 特徴: Azure DevOps Environmentsによる承認・監査機能
      - deployment: DeployJob
        displayName: 'Deploy to Dev'
        environment: 'development'
        pool:
          vmImage: 'ubuntu-latest'
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureWebAppContainer@1
                  displayName: 'Deploy to Azure Web App'
                  inputs:
                    azureSubscription: $(azureSubscription)
                    appName: 'az400-dev-webapp'
                    containers: '$(acrName).azurecr.io/az400webapp:$(Build.BuildId)'

  # ステージ3: ステージング環境へのデプロイ
  # 目的: DeployDevステージ成功後、Staging環境にデプロイ
  # 実行条件: DeployDevステージが成功
  - stage: DeployStaging
    displayName: 'Deploy to Staging'
    dependsOn: DeployDev
    jobs:
      # デプロイメントジョブ: Staging環境
      # 目的: 統合テスト環境へのデプロイと検証
      - deployment: DeployJob
        displayName: 'Deploy to Staging'
        environment: 'staging'
        pool:
          vmImage: 'ubuntu-latest'
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureWebAppContainer@1
                  displayName: 'Deploy to Staging Web App'
                  inputs:
                    azureSubscription: $(azureSubscription)
                    appName: 'az400-staging-webapp'
                    containers: '$(acrName).azurecr.io/az400webapp:$(Build.BuildId)'

  # ステージ4: 本番環境へのデプロイ
  # 目的: DeployStagingステージ成功後、Production環境にデプロイ
  # 実行条件: DeployStagingステージが成功
  # セキュリティ: Azure DevOps Environmentsの承認機能により、手動承認後にデプロイ可能
  - stage: DeployProd
    displayName: 'Deploy to Production'
    dependsOn: DeployStaging
    jobs:
      # デプロイメントジョブ: Production環境
      # 目的: 本番環境への最終デプロイ
      # 特徴: Environment承認、デプロイメント履歴、ロールバック機能
      - deployment: DeployJob
        displayName: 'Deploy to Production'
        environment: 'production'
        pool:
          vmImage: 'ubuntu-latest'
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureWebAppContainer@1
                  displayName: 'Deploy to Production Web App'
                  inputs:
                    azureSubscription: $(azureSubscription)
                    appName: 'az400-prod-webapp'
                    containers: '$(acrName).azurecr.io/az400webapp:$(Build.BuildId)'
```

#### 3.2 Service Connection設定

Azure DevOps > Project Settings > Service connections:

1. **Azure Resource Manager**:
   - Name: `AzureServiceConnection`
   - Subscription: 選択
   - Resource Group: `rg-az400-handson`

2. **Docker Registry**:
   - Name: `ACRServiceConnection`
   - Registry type: Azure Container Registry
   - Subscription: 選択
   - Azure Container Registry: `az400acr`

#### 3.3 Branch Protection CI/CD統合設定

> **📌 前提**: 基本的なBranch Protection設定は **Day 1 ステップ3.3** で完了済みです。ここではCI/CD統合時の追加設定を行います。

**Day 3で追加する設定**:

1. **GitHub リポジトリ** > **Settings** > **Branches** > 既存のルール編集
2. **Require status checks to pass before merging** を有効化:
   - ✅ **Require branches to be up to date before merging**
   - **Status checks that are required**:
     - `build` (GitHub Actionsのビルドジョブ)
     - `test` (GitHub Actionsのテストジョブ)
     - その他、`.github/workflows/ci.yml` で定義したジョブ名

**Work Item連携の自動チェック（オプション）**:

GitHub Actions で PR タイトルに `AB#123` 形式が含まれているかチェック:

```yaml
- name: Check Work Item Reference
  run: |
    if ! echo "${{ github.event.pull_request.title }}" | grep -qE 'AB#[0-9]+'; then
      echo "❌ PR titleにWork Item参照(AB#123)がありません"
      exit 1
    fi
```

**本番環境向け追加設定（参考）**:

- ✅ **Require approvals**: `1` 以上（Day 1では学習のため `0`）
- ✅ **Require linear history**: squash/rebaseのみ許可
- ✅ **Include administrators**: 管理者にもルールを適用

> **📝 注意**: Azure Repos使用時は「Branch Policies」で同様の設定を行います。

**Azure Pipelines使用時の補足**:

Azure Pipelinesを試験的に使用する場合（ステップ3）、Azure DevOpsで以下も設定可能:
- Azure DevOps > Project Settings > Repositories > GitHub connection
- Azure Pipelines の Build Validation を GitHub PR に統合可能

---

### ステップ 4: 比較検証（90分）

#### 4.1 GitHub Actions vs Azure Pipelines 比較表

| 観点 | GitHub Actions | Azure Pipelines |
|------|---------------|-----------------|
| **価格（Public）** | 無料 | 月1,800分無料 |
| **価格（Private）** | 月2,000分無料 | 月1パイプライン無料 |
| **並列ジョブ** | 20（無料）、180（Pro） | 1（無料）、購入可能 |
| **実行環境** | GitHub-hosted、Self-hosted | Microsoft-hosted、Self-hosted |
| **Marketplace** | GitHub Marketplace | Azure DevOps Marketplace |
| **YAMLサポート** | ✅ | ✅ |
| **Classic UI** | ❌ | ✅（レガシー） |
| **Artifacts統合** | GitHub Packages | Azure Artifacts |
| **Test Plans統合** | サードパーティ | ネイティブ |
| **Multi-stage** | ✅ | ✅ |
| **Environment保護** | ✅ | ✅ |
| **Matrix builds** | ✅ | ✅ |
| **Caching** | ✅ | ✅ |
| **Secrets管理** | GitHub Secrets | Variable Groups |

#### 4.2 使い分けガイドライン

**GitHub Actionsを選ぶケース**:
- ✅ GitHub中心の開発フロー
- ✅ シンプルなCI/CD
- ✅ OSS/Public リポジトリ
- ✅ GitHub Packagesを使用
- ✅ GitHub Marketplace活用

**Azure Pipelinesを選ぶケース**:
- ✅ エンタープライズシナリオ
- ✅ 複雑なマトリックスビルド
- ✅ Azure Artifacts・Test Plans統合
- ✅ Classic UI必要（レガシー対応）
- ✅ Azure DevOps中心の開発

**ハイブリッド構成**:
- GitHub（コード管理）+ Azure Pipelines（CI/CD）
- Azure Boards（Work Item）+ GitHub Actions（CI/CD）

#### 4.3 並列ジョブ理解

**Microsoft-hosted（GitHub Actions）**:
- 無料: 20並列ジョブ
- Pro: 180並列ジョブ
- Timeout: 6時間

**Microsoft-hosted（Azure Pipelines）**:
- 無料: 1並列ジョブ（月1,800分）
- 有料: 追加購入可能
- Timeout: 60分（無料）、360分（有料）

**Self-hosted**:
- 無制限並列ジョブ
- Timeout制限なし
- インフラ管理が必要

**試験ひっかけポイント**:
- Q: "Microsoft-hostedエージェントのタイムアウト対策は？"
- A: Self-hostedエージェント使用 or ジョブ分割

---

### ステップ 5: 総合演習（60分）

#### 5.1 完全なDevOpsワークフロー実行

**シナリオ**: 新機能追加（Day 1のWork Item連携を復習）

```bash
# 1. Work Item作成
# Azure Boards で User Story #523: 完全なDevOpsワークフロー実行 を作成

# 2. ブランチ作成
git checkout main
git pull
git checkout -b feature/AB#20-new-feature

# 3. コード変更
echo "New Feature" >> src/webapp/README.md

# 4. コミット（AB#記法）
git add .
git commit -m "feat: 新機能追加（AB#20）"
git push origin feature/AB#20-new-feature

# 5. PR作成（GitHub Web UI）
# - タイトル: "New Feature (AB#20)"
# - 本文に AB#20 記載
# - CODEOWNERSによる自動アサイン確認

# 6. CI実行確認
# - GitHub Actions CI実行
# - Azure Pipelines CI実行（Branch Policy）

# 7. レビュー → マージ

# 8. CD実行確認
# - Dev → Staging → Prod デプロイ

# 9. Application Insightsで監視
# - KQLでリクエスト確認
# - エラー率確認

# 10. Work Item自動クローズ確認
# - Azure Boards で AB#20 が Closed になっていることを確認
```

#### 5.2 Application Insightsでの監視（KQLクエリ実践）

デプロイ後、Application InsightsでKQLクエリを実行し、アプリケーションの動作を確認します。

##### 5.2.1 Application Insightsへのアクセス

1. **Azure Portal**にアクセス: https://portal.azure.com
2. リソースグループ `rg-az400-handson` を開く
3. **Application Insights** リソース（`az400-dev-ai`）をクリック
4. 左メニューから **Logs** を選択

##### 5.2.2 基本的なリクエスト確認

**クエリ1: 過去1時間のリクエスト一覧**

```kql
requests
| where timestamp > ago(1h)
| project timestamp, name, url, resultCode, duration, success
| order by timestamp desc
| take 50
```

**説明:**
- `ago(1h)`: 1時間前から現在まで
- `project`: 表示するカラムを選択
- `take 50`: 最新50件を表示

**期待される結果:**
```
timestamp              name    url                                    resultCode  duration  success
2026-05-10 10:30:15   GET /   https://az400-dev-webapp...           200         45.2      true
2026-05-10 10:29:45   GET /health  https://az400-dev-webapp...      200         12.5      true
```

**このクエリの活用方法:**

1. **保存方法**:
   - Save → **Save as query**
   - Description: 「過去1時間のリクエスト一覧（全HTTPステータスコード）」
   - Label: 「Daily-Check」

2. **アラート設定**: 不要（調査・確認用クエリ）

3. **ダッシュボード追加**:
   - Save → **Pin to Azure dashboard**
   - 「Pin to dashboard」ダイアログが表示されます

**設定項目:**

| 項目 | 選択肢 | 推奨設定 |
|------|--------|----------|
| **タブ** | Existing / Create new | 既存ダッシュボードがあれば **Existing**、初回は **Create new** |
| **Type** | Private / Shared | **Private**（個人用）または **Shared**（チーム共有用） |
| **Dashboard** | ドロップダウン | 既存ダッシュボードを選択 |

**具体的な手順:**

- **初回作成時**:
  1. **Create new** タブを選択
  2. Type: **Private** を選択（個人用）
  3. ダッシュボード名を入力: 「AZ400-Application-Insights-Dashboard」
  4. タイル名を入力: 「最新リクエスト一覧（過去1時間）」
  5. 「**Pin**」をクリック

- **2回目以降**:
  1. **Existing** タブを選択
  2. Type: **Private** のまま（または **Shared** でチーム共有）
  3. Dashboard: 「AZ400-Application-Insights-Dashboard」を選択
  4. タイル名を入力: クエリに応じた名前
  5. 「**Pin**」をクリック

> **📝 重要**: ダッシュボードにタイルを追加した後、**Configure tile settings**ダイアログが表示されます。ここで個別に以下を設定できます：
> - **Edit title セクション**:
>   - **Title**: タイルのタイトル（わかりやすい名前に変更推奨）
>   - **Subtitle**: サブタイトル（オプション、クエリの説明など）
> - **Time settings セクション**:
>   - **Override the dashboard time settings at the tile level**: チェックボックス（ダッシュボード全体と異なる時間範囲を設定可能）
>   - **Timespan**: 時間範囲（例: Past 24 hours）
>   - **Time granularity**: 時間粒度（例: Automatic）
>   - **Show time as**: タイムゾーン（例: UTC）
> 
> タイトル設定後、「**Apply**」をクリックして確定してください。

**用途**: 日常監視、トラブルシューティング時の即座確認

**AZ-400試験のポイント:**
- ✅ **Private vs Shared**: 個人用はPrivate、チーム全体で共有する場合はShared
- ✅ **ダッシュボード統合**: 複数のクエリを1つのダッシュボードにまとめて管理
- ✅ **Configure tile settings**: タイル追加後、個別にタイトルや時間設定をカスタマイズ可能

---

**クエリ2: 1時間ごとのリクエスト数（時系列グラフ）**

```kql
requests
| where timestamp > ago(24h)
| summarize RequestCount = count() by bin(timestamp, 1h)
| render timechart
```

**説明:**
- `bin(timestamp, 1h)`: タイムスタンプを1時間単位でグループ化
- `render timechart`: 時系列グラフで表示（AZ-400頻出）

**このクエリの活用方法:**

1. **保存方法**:
   - Save → **Save as query**
   - Description: 「リクエスト数の時系列推移（過去24時間）」
   - Label: 「Monitoring」

2. **アラート設定**（推奨）:
   - クエリを以下に変更してアラート作成:
   ```kql
   requests
   | where timestamp > ago(1h)
   | summarize RequestCount = count()
   | where RequestCount < 10
   ```
   - **New alert rule**をクリック → **Condition**タブで設定:
   
   **Create an alert rule - Condition設定:**
   
   | 項目 | 設定値 | 説明 |
   |------|--------|------|
   | **Signal name** | Custom log search | ドロップダウンから選択 |
   | **Query type** | ● Aggregated logs | ラジオボタンで選択（集計データでアラート） |
   | | ○ Single event (preview) | 選択しない（特定メッセージでのアラート用） |
   | **Search query** | 上記KQLクエリを入力 | 緑のチェックマークが表示されればOK |
   | **Threshold value** | `10` | 1時間あたりのリクエストが10未満でアラート |
   | **Evaluation frequency** | `5 minutes` | 5分ごとに評価 |
   
   - **Next: Actions >**をクリック → **Actions**タブで通知設定:
   
   **Create an alert rule - Actions設定:**
   
   Actionsタブには2つのオプションがあります:
   
   **オプション1: 既存のアクショングループを選択**
   
   | 手順 | 操作 | 説明 |
   |------|------|------|
   | 1 | **Select action groups** ボタンをクリック | 既存のアクショングループを選択するダイアログが開く |
   | 2 | **Subscription** ドロップダウンで選択 | アクショングループが作成されているサブスクリプション |
   | 3 | リストから選択 | チェックボックスで既存のアクショングループを選択<br>例: 「Application Insights Smart Detection」<br>Contains actions: 2 Email Azure Resource Management |
   | 4 | **Select** ボタンをクリック | 選択したアクショングループをアラートルールに適用 |
   
   **オプション2: 新しいアクショングループを作成**
   
   | 手順 | 操作 | 説明 |
   |------|------|------|
   | 1 | **Create action group** ボタンをクリック | 新規アクショングループ作成ダイアログが開く |
   | 2 | **Basics** タブで基本情報を入力 | |
   | | **Subscription** | アラートと同じサブスクリプション |
   | | **Resource group** | `rg-az400-handson` を選択 |
   | | **Action group name** | 例: `ag-az400-alerts` |
   | | **Display name** | 例: `AZ400 Alerts`（12文字以内） |
   | 3 | **Notifications** タブで通知方法を設定 | |
   | | **Notification type** | Email/SMS message/Push/Voice を選択 |
   | | **Email** | 開発チームのメールアドレス（例: team@example.com） |
   | | **SMS** | オンコール担当者の電話番号（オプション） |
   | | **Name** | 例: `Email-DevTeam` |
   | 4 | **Actions** タブ（オプション） | 自動アクションを設定 |
   | | **Automation Runbook** | 自動復旧スクリプト（サービス再起動など） |
   | | **Azure Function** | カスタム処理（Slack通知、チケット作成など） |
   | | **Logic App** | ワークフロー実行（複雑なエスカレーション） |
   | | **Webhook** | 外部システム連携（PagerDuty、Slackなど） |
   | 5 | **Review + create** → **Create** | アクショングループ作成完了 |
   
   **Email subject（オプション設定）:**
   
   Actionsタブの下部に「Email subject」フィールドがあり、メール通知の件名をカスタマイズできます。
   - デフォルト: Azure Monitor alert for [リソース名]
   - カスタマイズ例: 「【緊急】リクエスト数異常低下 - AZ400」
   
   - **Next: Details >**をクリック → **Details**タブでアラート名を入力:
     - **Alert rule name**: 「リクエスト数異常低下アラート」
     - **Description**: 「1時間あたりのリクエスト数が10未満の場合に通知」
     - **Severity**: `2 - Warning` または `1 - Error`（重要度に応じて選択）
   
   - **Review + create**をクリック → アラートルール作成完了
   
   - 用途: サービス停止や障害の早期検知
   
   **AZ-400試験のポイント:**
   - ✅ **Aggregated logs vs Single event**: 集計データのアラートには「Aggregated logs」を選択
   - ✅ **クエリ検証**: 緑のチェックマークでクエリの正当性を確認
   - ✅ **Action Group**: 複数のアラートで同じアクショングループを再利用可能
   - ✅ **Email vs SMS**: Email=一般通知、SMS=緊急通知（オンコール用）
   - ✅ **Severity レベル**: 0=Critical、1=Error、2=Warning、3=Informational、4=Verbose

3. **ダッシュボード追加**（強く推奨）:
   - Save → **Pin to Azure dashboard**
   - 「Pin to dashboard」ダイアログが表示されます

**設定項目:**

- **タブ**: **Existing** を選択（初回作成済みのダッシュボードを使用）
- **Type**: **Shared** を推奨（経営層・チーム全体で閲覧）
- **Dashboard**: 「AZ400-Application-Insights-Dashboard」を選択
- **タイル名**: 「リクエスト数推移（過去24時間）」
- 「**Pin**」をクリック

**用途**: トラフィック傾向の可視化、経営層向けレポート

**AZ-400試験のポイント:**
- ✅ **Shared dashboard**: 経営層向けメトリクスはチーム全体で共有
- ✅ **時系列グラフ**: トレンド分析に最適、異常値の早期発見

---

**クエリ3: エンドポイント別リクエスト数**

```kql
requests
| where timestamp > ago(24h)
| summarize RequestCount = count() by name
| order by RequestCount desc
```

**期待される結果:**
```
name           RequestCount
GET /          1250
GET /health    48
GET /secret    15
```

**このクエリの活用方法:**

1. **保存方法**:
   - Save → **Save as query**
   - Description: 「エンドポイント別リクエスト数（過去24時間）」
   - Label: 「API-Monitoring」

2. **アラート設定**（オプション）:
   - 特定エンドポイントへのアクセスが異常に多い場合のアラート:
   ```kql
   requests
   | where timestamp > ago(1h)
   | where name == "GET /secret"
   | summarize RequestCount = count()
   | where RequestCount > 100
   ```
   - **New alert rule**をクリック → **Condition**タブで設定:
   
   **Create an alert rule - Condition設定（エンドポイント監視）:**
   
   | 項目 | 設定値 | 説明 |
   |------|--------|------|
   | **Signal name** | Custom log search | ドロップダウンから選択 |
   | **Query type** | ● Aggregated logs | ラジオボタンで選択 |
   | **Search query** | 上記KQLクエリを入力 | 特定エンドポイント（/secret）の監視 |
   
   **Measurement セクション:**
   
   | 項目 | 設定値 | 説明 |
   |------|--------|------|
   | **Measure** | Table rows | ドロップダウンで選択（クエリ結果の行数をカウント） |
   | **Aggregation type** | Count | ドロップダウンで選択（件数集計） |
   | **Aggregation granularity** | 5 minutes | ドロップダウンで選択（5分ごとに集計） |
   
   **Split by dimensions セクション（オプション）:**
   
   | 項目 | 設定値 | 説明 |
   |------|--------|------|
   | **Dimension name** | Select dimension | 通常は選択不要（すべてのリクエストを集計） |
   | **Operator** | = | ディメンション選択時の演算子 |
   | **Dimension values** | 0 selected | 特定の値でフィルタ（通常は不要） |
   | **Include all future values** | ☐ | 新しいディメンション値を自動的に含める |
   
   > **📝 Note**: Split by dimensionsは、エンドポイントごと、リージョンごとなどに個別アラートを作成したい場合に使用します。今回はKQLクエリで既に `/secret` エンドポイントに絞り込んでいるため、ディメンション設定は不要です。
   
   **Alert logic セクション:**
   
   | 項目 | 設定値 | 説明 |
   |------|--------|------|
   | **Threshold value** | `100` | 1時間あたりのリクエストが100を超えたらアラート |
   | **Operator** | Greater than | 閾値より大きい場合に発火 |
   | **Evaluation frequency** | `5 minutes` | 5分ごとに評価 |
   
   - **Next: Actions >** → アクショングループを選択（セキュリティチーム向け通知）
   - **Next: Details >** → アラート名: 「機密エンドポイント異常アクセス検知」
   - **Severity**: `1 - Error`（セキュリティアラートは高優先度）
   
   - 用途: セキュリティ監視（機密エンドポイントへの異常アクセス検知）
   
   **AZ-400試験のポイント:**
   - ✅ **Split by dimensions**: 複数ディメンションで個別アラートを作成可能（リージョン別、環境別など）
   - ✅ **Measure = Table rows**: クエリ結果の行数をカウント（count()の結果ではなく結果セットの行数）
   - ✅ **セキュリティアラート**: Severity 1（Error）または 0（Critical）で設定

3. **ダッシュボード追加**（推奨）:
   - Save → **Pin to Azure dashboard**
   - 「Pin to dashboard」ダイアログが表示されます

**設定項目:**

- **タブ**: **Existing** を選択
- **Type**: **Private** または **Shared**（開発チーム用はShared推奨）
- **Dashboard**: 「AZ400-Application-Insights-Dashboard」を選択
- **タイル名**: 「エンドポイント別アクセス数」
- 「**Pin**」をクリック

**用途**: API使用状況の把握、人気エンドポイントの特定

---

##### 5.2.3 エラー率確認

**クエリ4: エラー率の計算**

```kql
requests
| where timestamp > ago(1h)
| extend isError = toint(success == false)
| summarize 
    TotalRequests = count(),
    ErrorCount = sum(isError),
    ErrorRate = 100.0 * sum(isError) / count()
| project TotalRequests, ErrorCount, ErrorRate
```

**説明:**
- `extend isError`: エラーかどうかを判定（0または1）
- `ErrorRate`: エラー率をパーセンテージで計算

**期待される結果（正常時）:**
```
TotalRequests  ErrorCount  ErrorRate
1200           0           0.0
```

**期待される結果（エラー発生時）:**
```
TotalRequests  ErrorCount  ErrorRate
1200           24          2.0
```

**このクエリの活用方法:**

1. **保存方法**:
   - Save → **Save as query**
   - Description: 「エラー率計算（過去1時間、5%超過でアラート用）」
   - Label: 「Critical」

2. **アラート設定**（必須・最重要）:
   - New alert rule → 条件:
     - **Threshold value**: `5` （エラー率5%を超えたら）
     - **Operator**: `Greater than`
     - **Aggregation granularity**: `5 minutes`
     - **Frequency of evaluation**: `5 minutes`
   - アクショングループ:
     - Email通知: 開発チーム全員
     - SMS通知: オンコール担当者
   - アラート名: 「エラー率5%超過（緊急対応必要）」
   - 用途: **本番環境の品質監視・SLA違反の早期検知**

3. **ダッシュボード追加**（必須）:
   - Save → **Pin to Azure dashboard**
   - 「Pin to dashboard」ダイアログが表示されます

**設定項目（重要）:**

- **タブ**: **Existing** を選択
- **Type**: **Shared** を強く推奨（全員が確認すべきメトリクス）
- **Dashboard**: 「AZ400-Application-Insights-Dashboard」を選択
- **タイル名**: 「エラー率（リアルタイム）」
- 「**Pin**」をクリック

**配置推奨**: ダッシュボードの最上部・左上（最重要メトリクス）

**用途**: 経営層向けダッシュボード、品質メトリクス、SLA監視

**AZ-400試験のポイント:**
- ✅ **エラー率は必須共有**: Shared dashboardで全員が常時監視
- ✅ **ダッシュボード配置**: 重要度の高いメトリクスは上部に配置

**AZ-400試験のポイント:**
- ✅ **エラー率5%**: SLA基準として頻出（95%成功率 = 5%エラー率）
- ✅ **5分間隔**: リアルタイム性と負荷のバランス
- ✅ **Critical アラート**: 即座にエスカレーション

---

**クエリ5: エラーの詳細確認**

```kql
requests
| where timestamp > ago(24h)
| where success == false
| project timestamp, name, url, resultCode, duration
| order by timestamp desc
```

**説明:**
- `success == false`: 失敗したリクエストのみフィルタ

**このクエリの活用方法:**

1. **保存方法**:
   - Save → **Save as query**
   - Description: 「エラー詳細一覧（トラブルシューティング用）」
   - Label: 「Troubleshooting」

2. **アラート設定**: 不要（調査用クエリ。クエリ4でエラー率アラート済み）

3. **ダッシュボード追加**: オプション（通常は不要）
   - エラー率（クエリ4）で異常検知した後、このクエリで詳細調査
   - 用途: エラー発生時の詳細調査に使用
   - 通常は保存クエリとして必要時に実行

**ピン留めする場合の設定:**
- **タブ**: Existing
- **Type**: Private（調査用、個人的に使用）
- **Dashboard**: 個別の調査用ダッシュボードを作成推奨
- **タイル名**: 「エラー詳細（トラブルシューティング用）」

---

##### 5.2.4 パフォーマンス分析（AZ-400重要）

**クエリ6: パーセンタイルでレスポンスタイム分析**

```kql
requests
| where timestamp > ago(1h)
| summarize 
    p50 = percentile(duration, 50),
    p95 = percentile(duration, 95),
    p99 = percentile(duration, 99),
    avg_duration = avg(duration)
| project 
    Median_ms = p50,
    P95_ms = p95,
    P99_ms = p99,
    Average_ms = avg_duration
```

**説明:**
- `percentile(duration, 95)`: 95%のリクエストがこの時間以内に完了
- **AZ-400頻出**: P95、P99の意味を理解する

**期待される結果:**
```
Median_ms  P95_ms  P99_ms  Average_ms
25.3       78.5    125.8   32.1
```

**解釈:**
- 中央値: 25.3ms（半分のリクエストが25.3ms以内）
- P95: 78.5ms（95%のリクエストが78.5ms以内）
- P99: 125.8ms（99%のリクエストが125.8ms以内）

**このクエリの活用方法:**

1. **保存方法**:
   - Save → **Save as query**
   - Description: 「レスポンスタイムP95パーセンタイル（SLA監視用）」
   - Label: 「Performance」

2. **アラート設定**（推奨・重要）:
   - P95が目標値を超えた場合のアラート:
   ```kql
   requests
   | where timestamp > ago(5m)
   | summarize P95 = percentile(duration, 95)
   | where P95 > 100
   ```
   - New alert rule → 条件:
     - **Threshold value**: `100` （P95が100ms超過）
     - **Aggregation granularity**: `5 minutes`
     - **Frequency of evaluation**: `5 minutes`
   - アラート名: 「レスポンスタイムP95が100ms超過（SLA警告）」
   - 用途: **パフォーマンスSLA監視（例: P95 < 100msを保証）**

3. **ダッシュボード追加**（強く推奨）:
   - Save → **Pin to Azure dashboard**
   - 「Pin to dashboard」ダイアログが表示されます

**設定項目（重要）:**

- **タブ**: **Existing** を選択
- **Type**: **Shared** を推奨（パフォーマンス監視はチーム全体で共有）
- **Dashboard**: 「AZ400-Application-Insights-Dashboard」を選択
- **タイル名**: 「レスポンスタイムパーセンタイル（P50/P95/P99）」
- 「**Pin**」をクリック

**配置推奨**: エラー率の右隣（主要メトリクスとして上部配置）

**用途**: パフォーマンストレンド監視、容量計画、SLA遵守確認

**AZ-400試験のポイント:**
- ✅ **P95はSLAの標準**: 「95%のリクエストが100ms以内」などの定義に使用
- ✅ **経営層向け**: パフォーマンスメトリクスは経営判断に重要

**AZ-400試験のポイント:**
- ✅ **P95パーセンタイル**: SLA定義に頻出（「95%のリクエストが100ms以内」など）
- ✅ **中央値 vs P95**: 中央値は外れ値の影響を受けにくいが、SLAにはP95/P99を使用
- ✅ **5分間隔監視**: リアルタイム性とコストのバランス

---

**クエリ7: 遅いリクエストの特定（1秒以上）**

```kql
requests
| where timestamp > ago(1h)
| where duration > 1000
| project timestamp, name, url, duration
| order by duration desc
```

**説明:**
- `duration > 1000`: 1000ミリ秒（1秒）以上のリクエスト

**このクエリの活用方法:**

1. **保存方法**:
   - Save → **Save as query**
   - Description: 「遅いリクエスト一覧（1秒以上、パフォーマンス調査用）」
   - Label: 「Troubleshooting」

2. **アラート設定**: 不要（調査用クエリ。クエリ6でP95アラート済み）

3. **ダッシュボード追加**: オプション（通常は不要）
   - パーセンタイル分析（クエリ6）で異常検知した後、このクエリで原因調査
   - 用途: パフォーマンス問題発生時の詳細調査
   - 通常は保存クエリとして必要時に実行

**ピン留めする場合の設定:**
- **タブ**: Existing
- **Type**: Private（調査用、個人的に使用）
- **Dashboard**: 個別の調査用ダッシュボードを作成推奨
- **タイル名**: 「遅いリクエスト（1秒以上）」

---

##### 5.2.5 環境別確認（オプション）

Web AppのcustomDimensionsにクラウドロール名が記録されています：

```kql
requests
| where timestamp > ago(1h)
| extend environment = tostring(customDimensions["ai.cloud.role"])
| summarize RequestCount = count() by environment
| order by RequestCount desc
```

**期待される結果:**
```
environment               RequestCount
az400-prod-webapp         500
az400-staging-webapp      200
az400-dev-webapp          100
```

**このクエリの活用方法:**

1. **保存方法**:
   - Save → **Save as query**
   - Description: 「環境別リクエスト数（Dev/Staging/Prod）」
   - Label: 「Environment-Monitoring」

2. **アラート設定**（推奨）:
   - 本番環境のリクエスト数が異常に少ない場合:
   ```kql
   requests
   | where timestamp > ago(1h)
   | extend environment = tostring(customDimensions["ai.cloud.role"])
   | where environment == "az400-prod-webapp"
   | summarize RequestCount = count()
   | where RequestCount < 50
   ```
   - アラート名: 「Production環境リクエスト異常低下」
   - 用途: 本番環境のトラフィック監視、障害検知

3. **ダッシュボード追加**（推奨）:
   - Save → **Pin to Azure dashboard**
   - 「Pin to dashboard」ダイアログが表示されます

**設定項目:**

- **タブ**: **Existing** を選択
- **Type**: **Shared** を推奨（環境別監視はチーム全体で共有）
- **Dashboard**: 「AZ400-Application-Insights-Dashboard」を選択
- **タイル名**: 「環境別トラフィック分散（Dev/Staging/Prod）」
- 「**Pin**」をクリック

**配置推奨**: ダッシュボードの下部セクション（環境監視エリア）

**用途**: 環境ごとの負荷分散状況、テスト環境の使用率監視、本番環境の優先監視

**AZ-400試験のポイント:**
- ✅ **環境別監視**: Dev/Staging/Prodの分離監視は本番運用の基本
- ✅ **Production優先**: 本番環境のトラフィックが他環境より多いことを確認

**AZ-400試験のポイント:**
- ✅ **環境別監視**: Dev/Staging/Prodの分離監視は本番運用の基本
- ✅ **customDimensions**: Application Insightsのカスタムプロパティ活用
- ✅ **Production優先**: 本番環境のみ厳格なアラート設定

---

##### 5.2.6 実践Tips（AZ-400試験対策）

**よく使うKQL関数:**

| 関数 | 用途 | 例 |
|-----|------|-----|
| `bin()` | 時間集計 | `bin(timestamp, 1h)` |
| `extend` | カラム追加 | `extend isError = success == false` |
| `project` | カラム選択 | `project timestamp, name` |
| `percentile()` | パーセンタイル計算 | `percentile(duration, 95)` |
| `summarize` | 集計 | `summarize count() by name` |
| `where` | フィルタ | `where success == false` |
| `ago()` | 相対時間 | `ago(1h)`, `ago(24h)` |

**AZ-400試験でよく問われるポイント:**
- ✅ **Cycle Time vs Lead Time**: Cycleは作業開始→完了、Leadは作成→完了
- ✅ **P95パーセンタイル**: 95%のリクエストがこの時間以内
- ✅ **bin()関数**: 時間集計に必須（1h、5m、1dなど）
- ✅ **extend vs project**: extendはカラム追加、projectはカラム選択

##### 5.2.7 保存とアラート設定（発展）

1. **クエリの保存**:
   - クエリを実行後、上部の「**Save**」ボタンをクリック
   - ドロップダウンメニューが表示されるので、「**Save as query**」を選択
   - 「Save as query」ダイアログが表示されます

**設定項目の詳細:**

| フィールド | 設定内容 | 推奨値 |
|-----------|---------|--------|
| **Type query description** | クエリの説明文を入力 | 「過去1時間のリクエスト一覧を表示」など、クエリの目的を簡潔に記述 |
| **Save as Legacy query** | レガシー形式で保存（チェックボックス） | ☐ チェックしない（新形式を推奨） |
| **Path** | 保存先の選択 | ☑ **Save to the default query pack**（推奨） |
| **Tags - Resource type** | リソースタイプ | **Application Insights**（自動選択済み） |
| **Tags - Category** | カテゴリ分類（オプション） | ドロップダウンから既存のカテゴリを選択（新規作成不可） |
| **Tags - Label** | ラベル（オプション） | ドロップダウンから選択、または「**Create new label**」で新規作成可 |

**具体的な入力例:**

```
【必須項目】
Type query description:
  「過去1時間のリクエスト一覧（全HTTPステータスコード）」

Path:
  ☑ Save to the default query pack

【オプション項目】
Tags - Category:
  既存のカテゴリから選択（0 selected = 未選択でもOK）

Tags - Label:
  既存のラベルから選択、または「Create new label」をクリックして新規作成
  例: 「Daily-Check」「Production」など
```

**保存完了:**
   - 「**Save**」ボタンをクリック
   - 保存したクエリは「**Logs → Queries → My queries**」から再利用可能

**AZ-400試験のポイント:**
- ✅ **Type query description**: 検索時に見つけやすい説明を記述
- ✅ **default query pack**: チーム間でクエリを共有可能
- ✅ **Tags**: 大量のクエリを分類・整理するために重要

---

**Saveメニューの選択肢の説明:**

| 選択肢 | 用途 | いつ使う？ |
|-------|------|-----------|
| **Save as query** | クエリを保存して再利用 | よく使うKQLクエリを保存（推奨） |
| **Save as function** | KQL関数として保存 | 複雑なロジックを関数化して他のクエリで再利用 |
| **Pin to Azure dashboard** | Azure Portalダッシュボードに追加 | 常時監視したいメトリクス |
| **Pin to Grafana dashboard** | Grafanaダッシュボードに追加 | Grafana使用時のみ |
| **Send to workbook** | Azure Workbookに送信 | 複数クエリを組み合わせたレポート作成 |

**AZ-400試験のポイント:**
- ✅ **Save as query**: 最も一般的、クエリの再利用に最適
- ✅ **Pin to dashboard**: リアルタイム監視用、経営層向けダッシュボード
- ✅ **Workbook**: 複数のクエリ・グラフを組み合わせた総合レポート

2. **アラートルールの作成**:
   - 保存したクエリを開く（Logs → Queries → My queries → 保存したクエリ名）
   - クエリを実行後、上部の「**New alert rule**」をクリック
   - 条件設定:
     - **Threshold value**: `5` （エラー率5%を超えたら）
     - **Evaluation frequency**: `5 minutes` （5分ごとに評価）
   - アクショングループ: 
     - 新規作成またはリソースグループから既存を選択
     - 通知方法: Email/SMS/Push/Voice
     - Email: 通知先アドレスを入力
   - アラートルール名を入力（例: "エラー率5%超過アラート"）
   - 「**Create alert rule**」をクリック

3. **ダッシュボードへのピン留め**:
   - クエリを実行後、上部の「**Save**」→「**Pin to Azure dashboard**」を選択
   - ダッシュボード選択:
     - **Create new**: 新規ダッシュボード作成
     - **Existing**: 既存ダッシュボードに追加
   - タイル名を入力（例: "リクエスト数（過去24時間）"）
   - 「**Pin**」をクリック
   - Azure Portalのホーム画面でダッシュボードを確認可能

---

#### 5.3 動作確認（curlコマンド）

デプロイが完了したら、curlコマンドまたはブラウザで各環境の動作を確認します。

##### 5.3.1 Dev環境の動作確認

```bash
# 1. ルートエンドポイント
curl https://az400-dev-webapp.azurewebsites.net/

# 期待される結果:
# {"message":"Hello from AZ-400 Handson!","version":"1.0.0","environment":"development"}

# 2. ヘルスチェック
curl https://az400-dev-webapp.azurewebsites.net/health

# 期待される結果:
# {"status":"healthy","timestamp":"2026-05-10T10:30:15.123Z"}

# 3. Key Vaultシークレット取得テスト
curl https://az400-dev-webapp.azurewebsites.net/secret

# 期待される結果:
# {"secretName":"demo-secret","value":"********","source":"Azure Key Vault"}
```

##### 5.3.2 Staging環境の動作確認

```bash
# Staging環境も同様にテスト
curl https://az400-staging-webapp.azurewebsites.net/
curl https://az400-staging-webapp.azurewebsites.net/health
```

##### 5.3.3 Production環境の動作確認

```bash
# Production環境の確認（本番環境）
curl https://az400-prod-webapp.azurewebsites.net/
curl https://az400-prod-webapp.azurewebsites.net/health
```

##### 5.3.4 ブラウザでの確認

各URLをブラウザで開いても確認できます：
- Dev: https://az400-dev-webapp.azurewebsites.net/
- Staging: https://az400-staging-webapp.azurewebsites.net/
- Production: https://az400-prod-webapp.azurewebsites.net/

---

#### 5.4 Work Item自動クローズ確認

GitHub PullRequestをマージする際、コミットメッセージに `AB#20` を含めることで、Azure BoardsのWork Itemが自動的にクローズされます。

##### 5.4.1 確認手順

1. **Azure Boards**を開く:
   ```
   https://dev.azure.com/{your-org}/az400-handson/_workitems
   ```

2. Work Item `AB#20`（または該当するID）を検索

3. **State**が `Closed` または `Done` になっていることを確認

4. **History**タブで、GitHubからの自動更新を確認:
   ```
   "Fixed by commit: abc123... (feat: 新機能追加（AB#20）)"
   ```

##### 5.4.2 AB#記法のバリエーション（AZ-400重要）

以下のキーワードでWork Itemを自動クローズできます：

| キーワード | 例 | 効果 |
|-----------|-----|------|
| `fixes AB#123` | `git commit -m "fixes AB#123: バグ修正"` | Work Item #123をクローズ |
| `resolves AB#123` | `git commit -m "resolves AB#123: 対応完了"` | Work Item #123をクローズ |
| `closes AB#123` | `git commit -m "closes AB#123: タスク完了"` | Work Item #123をクローズ |
| `AB#123` | `git commit -m "feat: 新機能（AB#123）"` | リンクのみ（クローズしない） |

**AZ-400試験のポイント:**
- ✅ `fixes`、`resolves`、`closes`は自動クローズのトリガー
- ✅ `AB#123`のみの記載はリンクのみ（クローズしない）
- ✅ マージされたPRのコミットメッセージが対象

---

## ✅ Day 3 成果物チェックリスト

### GitHub Actions
- [ ] CI Pipeline作成・動作確認
- [ ] CD Pipeline作成・動作確認
- [ ] 環境別デプロイ実装（Dev/Staging/Prod）
- [ ] Dependabot設定
- [ ] CodeQL設定

### Azure Pipelines
- [ ] YAML Pipeline作成・動作確認
- [ ] Multi-stage Pipeline実装
- [ ] Service Connection設定
- [ ] Branch Policy統合

### 比較・理解
- [ ] GitHub Actions vs Azure Pipelines 比較表作成
- [ ] 使い分けガイドライン理解
- [ ] 並列ジョブの概念理解
- [ ] ハイブリッド構成理解

### DevOpsワークフロー
- [ ] Work Item → Branch → Commit → PR → CI → CD の完全フロー実行
- [ ] AB#記法による自動リンク確認
- [ ] Application Insightsで監視確認

---

## 🎓 3日間の学習完了！

### 理解度最終確認

以下の質問に即答できるか確認：

1. **Key Vault IAMとAccess Policiesの違いは？**
2. **system-assignedとuser-assignedの使い分けは？**
3. **Cycle TimeとLead Timeの違いは？**
4. **SemVerでバグ修正はどのバージョンを上げる？**
5. **CODEOWNERSの配置場所は？**
6. **GitHub FlowとGitFlowの違いは？**
7. **95パーセンタイルの意味は？**
8. **extendとprojectの違いは？**
9. **GitHub ActionsとAzure Pipelinesの使い分けは？**
10. **Microsoft-hostedエージェントのタイムアウト対策は？**

### 克服した弱点領域

✅ **Azure DevOps管理** - Key Vault IAM、Managed Identity、保持ポリシー  
✅ **Git/GitHub運用** - SemVer、CODEOWNERS、ブランチ戦略  
✅ **Azure Boards** - Cycle/Lead Time、依存関係管理  
✅ **App Insights/KQL** - KQLクエリ、メトリクス可視化  
✅ **Azure Pipelines** - 並列ジョブ、エージェントプール  
✅ **CI/CD** - GitHub Actions vs Azure Pipelines  

---

## 📚 次のステップ

### 試験準備
1. Microsoft Learn の AZ-400 ラーニングパス復習
2. 模擬試験再受験（弱点克服確認）
3. 公式ドキュメント精読

### 継続学習
- Azure Test Plans実践
- GitHub Advanced Security
- Infrastructure as Code（Terraform）
- Kubernetes / AKS統合

---

**3日間お疲れ様でした！AZ-400試験、頑張ってください！🚀🎉**
