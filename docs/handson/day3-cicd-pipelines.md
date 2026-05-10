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
- Web App デプロイ済み

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

> **📝 注意**: Day 2で既に `AZURE_CREDENTIALS` を設定済みの場合、この手順は不要です。

GitHub > Settings > Secrets and variables > Actions に以下を設定:

- `AZURE_CREDENTIALS`: 上記JSON全体（Service Principalの認証情報）

**備考**: 
- ACRへのログインは `az acr login` を使用するため、ACR個別の認証情報（ACR_USERNAME/PASSWORD）は不要です
- `AZURE_CREDENTIALS` のみでACR + Web Appの両方にアクセス可能です

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

#### 3.3 Branch Protection設定

**本ハンズオンではGitHubリポジトリを使用するため、GitHub Branch Protection Rulesを設定します。**

> **📝 注意**: Azure Repos使用時は「Branch Policies」、GitHub使用時は「Branch Protection Rules」となります。

**設定手順**:

1. **GitHub リポジトリ** > **Settings** > **Branches**
2. **Branch protection rules** > **Add rule**
3. **Branch name pattern**: `main`
4. 以下の設定を有効化:

**必須設定**:

- ✅ **Require a pull request before merging**
  - **Require approvals**: `1`
  - ✅ **Dismiss stale pull request approvals when new commits are pushed**
  - ✅ **Require review from Code Owners**（`.github/CODEOWNERS`設定済みの場合）

- ✅ **Require status checks to pass before merging**
  - ✅ **Require branches to be up to date before merging**
  - **Status checks that are required**:
    - `build` (CI - GitHub Actionsワークフロー)
    - `test` (テストジョブ)
    - その他、定義したジョブ名

- ✅ **Require conversation resolution before merging**
  - すべてのコメントを解決してからマージ

**推奨設定**:

- ✅ **Require linear history**: squash/rebaseのみ許可（クリーンな履歴）
- ✅ **Include administrators**: 管理者にもルールを適用
- ❌ **Allow force pushes**: オフ（履歴保護）
- ❌ **Allow deletions**: オフ（ブランチ保護）

**Work Item連携について**:

GitHubには「Work item linking必須」機能がないため、以下で代替:

1. **コミットメッセージ規約**: `AB#123`形式を必須化
2. **PR テンプレート**（`.github/pull_request_template.md`）で明示
3. **GitHub Actions で自動チェック**（オプション）:

```yaml
- name: Check Work Item Reference
  run: |
    if ! echo "${{ github.event.pull_request.title }}" | grep -qE 'AB#[0-9]+'; then
      echo "❌ PR titleにWork Item参照(AB#123)がありません"
      exit 1
    fi
```

**Azure Pipelines使用時の補足**:

Azure Pipelinesを試験的に使用する場合（Day 3ステップ3）、Azure DevOpsで以下も設定可能:
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
# Azure Boards で User Story #20: 新機能追加 を作成

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

#### 5.2 動作確認

```bash
# Web Appアクセス
curl https://az400-dev-webapp.azurewebsites.net/

# ヘルスチェック
curl https://az400-dev-webapp.azurewebsites.net/health

# Key Vaultテスト
curl https://az400-dev-webapp.azurewebsites.net/secret
```

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
