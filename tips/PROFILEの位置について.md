了解です。  
**「プロファイルをローカル（OneDrive 以外）で使う」ための現実的で安全な方法**を、影響の少ない順に説明します。

結論から言うと、**おすすめは方法①**です。

***

# ✅ 方法①【推奨】ローカルに“本体”を置き、OneDrive 側は呼び出し専用にする

👉 **OneDrive の既知フォルダー移動 (KFM) はそのまま**
👉 **PowerShell の実体設定はローカルに分離**

Microsoft 公式・実運用でも最もトラブルが少ない方法です [\[stackoverflow.com\]](https://stackoverflow.com/questions/74896830/how-can-i-change-powershells-profile-to-point-to-the-local-documents-folder-in)

***

## 手順

### 1️⃣ ローカル用の PowerShell フォルダーを作る

```powershell
mkdir $env:USERPROFILE\Documents\PowerShell -Force
```

### 2️⃣ ローカルに「本命プロファイル」を作る

```powershell
notepad $env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
```

ここに **本来書きたかった設定** をすべて書きます。

***

### 3️⃣ OneDrive 側のプロファイルは「呼び出すだけ」にする

現在使われている（OneDrive 配下の）プロファイルを開きます：

```powershell
notepad $PROFILE
```

中身を **すべて消して**、これだけにします：

```powershell
& "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
```

✅ これで：

*   PowerShell / VS Code は **仕様どおり OneDrive 側を読む**
*   しかし **実際の設定は完全にローカル**
*   OneDrive 同期トラブル・複数 PC 差分を回避

***

### 4️⃣ VS Code 用（Microsoft.VSCode\_profile.ps1）も同様にする（重要）

```powershell
notepad $env:USERPROFILE\OneDrive\Documents\PowerShell\Microsoft.VSCode_profile.ps1
```

中身：

```powershell
& "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
```

✅ VS Code / ターミナル / デバッグ実行すべて統一されます [\[github.com\]](https://github.com/microsoft/vscode/issues/264688)

***

## ✅ この方法のメリット

*   OneDrive 設定を壊さない
*   管理者権限・レジストリ操作不要
*   Windows Update の影響をほぼ受けない
*   PowerShell / VS Code 両対応
*   失敗しても即戻せる

***

# ⚠️ 方法②（非推奨）OneDrive の「ドキュメント」同期自体をやめる

OneDrive 設定 →  
**設定 → 同期とバックアップ → バックアップの管理**  
で「ドキュメント」をオフにすると、

    C:\Users\<username>\Documents

に戻ります [\[learn.microsoft.com\]](https://learn.microsoft.com/ja-jp/sharepoint/redirect-known-folders)

❌ ただし：

*   既存ファイルの移動が発生
*   Office / 他アプリへの影響あり
*   企業ポリシー環境では不可な場合あり

👉 個人用途でも **方法①の方が安全** です。

***

# ❌ 方法③（非推奨）レジストリを書き換える

Stack Overflow 等では紹介されていますが、

*   Windows 全体の「ドキュメント定義」を変更
*   影響範囲が非常に広い

ためおすすめしません [\[stackoverflow.com\]](https://stackoverflow.com/questions/74896830/how-can-i-change-powershells-profile-to-point-to-the-local-documents-folder-in)

***

# ✅ まとめ（おすすめ構成）

| 項目           | 状態       |
| ------------ | -------- |
| OneDrive KFM | ✅ そのまま   |
| 実体プロファイル     | ✅ ローカル   |
| OneDrive 側   | ✅ 呼び出し専用 |
| VS Code      | ✅ 完全対応   |
| 安定性          | ✅ 高い     |

***

もし次に：

*   VS Code **だけ** 別プロファイルにしたい
*   PC ごとに設定を分けたい
*   `-NoProfile` で起動したい
*   `$PROFILE` の種類（AllHosts / CurrentHost）を整理したい

などあれば、そこもピンポイントで案内できます。
