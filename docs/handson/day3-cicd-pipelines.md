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

```bash
# Service Principal作成（GitHub ActionsがAzureにアクセスするため）
az ad sp create-for-rbac \
  --name "sp-az400-github-actions" \
  --role contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-az400-handson \
  --sdk-auth

# 出力をコピー（GitHub Secretsに保存）
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

GitHub > Settings > Secrets and variables > Actions:

- `AZURE_CREDENTIALS`: 上記JSON全体
- `AZURE_SUBSCRIPTION_ID`: サブスクリプションID
- `ACR_LOGIN_SERVER`: az400acr.azurecr.io
- `ACR_USERNAME`: ACRのユーザー名
- `ACR_PASSWORD`: ACRのパスワード

#### 1.3 CI Pipeline作成

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
  build-and-test:
    name: Build and Test
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          cache-dependency-path: ${{ env.WORKING_DIRECTORY }}/package-lock.json
      
      - name: Install dependencies
        run: npm ci
        working-directory: ${{ env.WORKING_DIRECTORY }}
      
      - name: Run linter
        run: npm run lint || echo "No lint script"
        working-directory: ${{ env.WORKING_DIRECTORY }}
      
      - name: Run tests
        run: npm test
        working-directory: ${{ env.WORKING_DIRECTORY }}
      
      - name: Build application
        run: npm run build || echo "No build script"
        working-directory: ${{ env.WORKING_DIRECTORY }}
  
  docker-build:
    name: Build and Push Docker Image
    runs-on: ubuntu-latest
    needs: build-and-test
    if: github.event_name == 'push'
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Login to Azure Container Registry
        uses: docker/login-action@v2
        with:
          registry: ${{ secrets.ACR_LOGIN_SERVER }}
          username: ${{ secrets.ACR_USERNAME }}
          password: ${{ secrets.ACR_PASSWORD }}
      
      - name: Build and push Docker image
        uses: docker/build-push-action@v4
        with:
          context: ${{ env.WORKING_DIRECTORY }}
          push: true
          tags: |
            ${{ secrets.ACR_LOGIN_SERVER }}/az400webapp:${{ github.sha }}
            ${{ secrets.ACR_LOGIN_SERVER }}/az400webapp:latest
      
      - name: Image scan (Trivy)
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ secrets.ACR_LOGIN_SERVER }}/az400webapp:${{ github.sha }}
          format: 'sarif'
          output: 'trivy-results.sarif'
      
      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'
```

#### 1.4 CD Pipeline作成

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
  deploy-dev:
    name: Deploy to Development
    runs-on: ubuntu-latest
    if: github.event.workflow_run.conclusion == 'success'
    environment:
      name: development
      url: https://${{ env.AZURE_WEBAPP_NAME }}.azurewebsites.net
    
    steps:
      - name: Login to Azure
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Deploy to Azure Web App
        uses: azure/webapps-deploy@v2
        with:
          app-name: ${{ env.AZURE_WEBAPP_NAME }}
          images: ${{ secrets.ACR_LOGIN_SERVER }}/az400webapp:${{ github.sha }}
      
      - name: Smoke test
        run: |
          sleep 30
          curl -f https://${{ env.AZURE_WEBAPP_NAME }}.azurewebsites.net/health || exit 1
  
  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: deploy-dev
    environment:
      name: staging
      url: https://az400-staging-webapp.azurewebsites.net
    
    steps:
      - name: Login to Azure
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Deploy to Staging Web App
        uses: azure/webapps-deploy@v2
        with:
          app-name: 'az400-staging-webapp'
          images: ${{ secrets.ACR_LOGIN_SERVER }}/az400webapp:${{ github.sha }}
      
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
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Deploy to Production Web App
        uses: azure/webapps-deploy@v2
        with:
          app-name: 'az400-prod-webapp'
          images: ${{ secrets.ACR_LOGIN_SERVER }}/az400webapp:${{ github.sha }}
      
      - name: Notify deployment
        run: |
          echo "Production deployment completed!"
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

---

## 📋 午後セッション（3-4時間）

### ステップ 3: Azure Pipelines実装（120分）

#### 3.1 Azure Pipelines YAML作成

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
  - stage: Build
    displayName: 'Build and Test'
    jobs:
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

  - stage: DeployDev
    displayName: 'Deploy to Development'
    dependsOn: Build
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
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

  - stage: DeployStaging
    displayName: 'Deploy to Staging'
    dependsOn: DeployDev
    jobs:
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

  - stage: DeployProd
    displayName: 'Deploy to Production'
    dependsOn: DeployStaging
    jobs:
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

#### 3.3 Branch Policy設定

Azure DevOps > Repos > Branches > main > Branch policies:

- ✅ Require a minimum number of reviewers: 1
- ✅ Build validation:
  - Build pipeline: azure-pipelines.yml
  - Policy requirement: Required
- ✅ Work item linking: Required

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
