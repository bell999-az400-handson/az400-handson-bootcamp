# GitHub Copilot Instructions - AZ-400 Exam Practice

このリポジトリはAZ-400試験対策用の3日間集中ハンズオン環境です。

## ルール

### Git/GitHub操作
- **SemVer**: Major.Minor.Patch形式（例: 1.2.3）
  - Major: 互換性のない変更
  - Minor: 後方互換性のある機能追加
  - Patch: バグ修正
- **CODEOWNERS**: `.github/CODEOWNERS`に配置
- **Work Item参照**: `AB#123`形式でコミット
- **Commit message**: `fixes AB#123: 説明`形式
- **Branch naming**: `feature/AB#123-description`形式

### Azure Bicep
- **Key Vault**:
  - データプレーン権限（シークレット読み書き）: Access Policies
  - 管理プレーン権限（Key Vault自体の管理）: IAM
  - 混同しないこと！
- **Managed Identity**:
  - system-assigned: 単一リソース用（1対1）
  - user-assigned: 複数リソースで共有（1対多）
- **シークレット管理**: Azure Key Vault必須（コードに直書き禁止）
- **パラメータファイル**: dev/staging/prod環境別に作成

### Application Insights & KQL
- **時間集計**: `bin(TimeGenerated, 1h)` または `bin(TimeGenerated, 5m)`
- **カラム追加**: `extend newColumn = calculation`
- **カラム選択**: `project column1, column2`
- **パーセンタイル**: `percentile(duration, 95)` ← 95%のリクエストがこの時間以内
- **フィルタ**: `where` を使用

### CI/CD選択基準
- **GitHub Actions**: 
  - GitHub中心の開発フロー
  - シンプルなCI/CD
  - GitHub Marketplace活用
  - GitHub Packagesとの統合
  
- **Azure Pipelines**: 
  - エンタープライズシナリオ
  - 複雑なマトリックスビルド
  - Azure Artifacts・Test Plansとのネイティブ連携
  - Classic UI + YAML両方のサポート

- **ハイブリッド構成も可能**: GitHub（コード） → Azure Pipelines（CI/CD）

### ブランチ戦略
- **GitHub Flow**: 
  - feature → PR → 本番デプロイ → mainマージ
  - シンプル、継続的デプロイ向け
  
- **GitFlow**: 
  - develop/main分離
  - リリースブランチ使用
  - 計画的リリース向け
  
- **Trunk-based**: 
  - mainに直接コミット
  - フィーチャーフラグ使用
  - 高頻度デプロイ向け

### Azure Boards統合
- **Cycle Time**: 作業開始（Active）→ 完了（Done）までの時間
- **Lead Time**: 作成（New）→ 完了（Done）までの時間
- **Work Item階層**: Epic → Feature → User Story → Task
- **依存関係**: Predecessor（先行）/ Successor（後続）

## Copilotへの推奨質問フレーズ

### セキュリティ・権限
- "Key VaultのIAMとAccess Policiesの違いは？"
- "system-assignedとuser-assignedの使い分けは？"
- "この要件で最小権限を満たすRBACロールは？"

### バージョニング
- "この変更はSemVerでどのバージョンを上げるべき？"
- "バグ修正なのでPATCHを上げる、で合ってる？"

### CI/CD
- "この要件ならGitHub ActionsとAzure Pipelinesどちらが最適？"
- "並列ジョブの設定方法は？"
- "Self-hostedエージェントの認証方法は？"

### KQL
- "95パーセンタイルのレスポンスタイムを取得するKQLは？"
- "extendとprojectの違いは？"
- "1時間ごとのリクエスト数を集計するには？"

### ブランチ戦略
- "GitHub FlowとGitFlowの違いは？"
- "継続的デプロイならどのブランチ戦略が最適？"

## AZ-400試験対策ポイント

### 試験配分（2026年4月24日版シラバス）
- プロセスとコミュニケーション: 10-15%
- ソース管理戦略: 10-15%
- **ビルド・リリースパイプライン: 50-55%** ⭐ 最重要
- セキュリティ・コンプライアンス: 10-15%
- インストルメンテーション: 5-10%

### 頻出ひっかけポイント
1. Key Vault IAM vs Access Policies
2. Cycle Time vs Lead Time
3. system-assigned vs user-assigned Managed Identity
4. GitHub Actions vs Azure Pipelines の使い分け
5. SemVer のバージョン選択（Major/Minor/Patch）
6. ブランチ戦略の適用判断

## 学習の進め方

このリポジトリは3日間で以下を実践します：

- **Day 1**: Git/GitHub高度操作 + Azure基礎
- **Day 2**: Azure Security（Key Vault/Managed Identity）+ App Insights
- **Day 3**: CI/CD完全マスター（GitHub Actions vs Azure Pipelines）

詳細は `docs/handson/` を参照してください。


## 処理ルール
- スクリプトで同一処理を３回失敗したら原因を調査して対策するようにしてください。
- pythonを実行する場合は、事前にuv仮想環境をインストールし、仮想環境を起動してから実行するようにしてください。また、必要なライブラリはrequirements.txtに記載してください。