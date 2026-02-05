# Pencil WSL Bridge

**[English](README.md)** | **[中文](README_zh.md)** | **[日本語](README_ja.md)**

WSL を通じて Windows 上で [Pencil](https://pencil.evolany.com/) を実行し、MCP プロトコルを Warp ターミナルにブリッジします。

## なぜこのプロジェクトが必要？

Pencil は Linux 版のみ提供されています。このプロジェクトは WSL 内で Pencil を実行し、MCP Server を Windows 側にブリッジします。

## 解決した問題

1. **プロキシ問題** - WSL は `localhost` プロキシにアクセスできないため、Windows ホスト IP を使用
2. **FUSE マウント問題** - AppImage の FUSE は WSL で不安定なため、squashfs を展開して直接実行
3. **MCP 引数形式** - MCP Server は `--app` ではなく `-app` を使用
4. **WSL stderr 干渉** - WSL プロキシ警告が MCP stdio 通信を妨害、`.cmd` ラッパーで抑制
5. **ファイル保存場所** - Ctrl+S はデフォルトで Linux ファイルシステムに保存され、Windows からアクセスしにくい

## ワンクリックインストール

PowerShell で実行：
```powershell
irm https://raw.githubusercontent.com/a614455654-ctrl/pencil-wsl-bridge/main/install.ps1 | iex
```

インストーラーが自動的に：
- WSL ディストロとユーザーを検出
- Pencil をダウンロード・展開
- プロキシ設定を構成
- デスクトップショートカットと MCP ラッパーを作成
- AI ツール用の MCP 設定を出力

## 手動インストール

### 前提条件

- Windows 10/11 + WSL2
- Ubuntu (WSL)
- プロキシソフト（例：Clash）がポート `7897` でリッスン

### 1. WSL Ubuntu にインストール

```bash
# Pencil AppImage をダウンロード
wget https://github.com/nicepkg/pencil/releases/latest/download/Pencil-linux-x86_64.AppImage

# squashfs を展開（FUSE 問題を回避）
chmod +x Pencil-linux-x86_64.AppImage
./Pencil-linux-x86_64.AppImage --appimage-extract
mv squashfs-root ~/squashfs-root

# スクリプトをコピー
cp scripts/start-pencil.sh ~/
cp scripts/pencil-mcp.sh ~/
chmod +x ~/start-pencil.sh ~/pencil-mcp.sh
```

### 2. プロキシ IP の設定

Windows ホスト IP を取得：
```powershell
(Get-NetIPAddress -InterfaceAlias "vEthernet (WSL*)" -AddressFamily IPv4).IPAddress
```

両方のスクリプト内のプロキシアドレスを編集（`172.25.176.1` を自分の IP に置き換え）。

### 3. デスクトップショートカット

`windows/启动Pencil.bat` と `windows/启动Pencil.ps1` をデスクトップにコピーしてください。

## MCP 設定（Warp）

### 方法 1：.cmd ラッパー（推奨）

`C:\Users\<ユーザー名>\pencil-mcp.cmd` を作成：
```batch
@echo off
wsl -d Ubuntu -u <ユーザー名> -e /home/<ユーザー名>/pencil-mcp.sh 2>nul
```

Warp MCP 設定：
```json
{
  "Pencil": {
    "command": "C:\\Users\\<ユーザー名>\\pencil-mcp.cmd",
    "args": [],
    "env": {},
    "start_on_launch": true
  }
}
```

### 方法 2：WSL 直接呼び出し

```json
{
  "Pencil": {
    "command": "wsl",
    "args": ["-d", "Ubuntu", "-u", "<ユーザー名>", "-e", "/home/<ユーザー名>/pencil-mcp.sh"],
    "env": {},
    "start_on_launch": true
  }
}
```

> ⚠️ WSL がプロキシ警告を出力して `Transport closed` エラーが発生する場合は、方法 1 を使用してください。

## トラブルシューティング

### 問題 1：Transport closed

**原因**：WSL の stderr 出力（プロキシ警告など）が MCP stdio 通信を妨害。

**解決**：`.cmd` ラッパースクリプトで `2>nul` を追加して stderr を抑制。

### 問題 2：WebSocket not connected to app: desktop

**原因**：MCP Server が Pencil GUI に接続できない。

**解決**：
1. 先に Pencil GUI を起動（`启动Pencil.bat` をダブルクリック）
2. Pencil が完全に読み込まれてから MCP を有効化
3. ポートファイルの存在を確認：`~/.pencil/apps/desktop`

### 問題 3：MCP 引数形式エラー

**原因**：MCP Server はシングルダッシュ引数を使用。

**解決**：`--app desktop` ではなく `-app desktop` を使用。

### 問題 4：保存したファイルが見つからない / 保存プロンプトが出ない

**原因**：Pencil は WSL 内で実行されているため、Ctrl+S は Linux ファイルシステム（例：`/home/ユーザー名/...`）にファイルを保存します。Windows エクスプローラーからは直接見えません。

**解決**：**File → Save As** を使用し、WSL マウント経由で Windows パスに保存：
```
/mnt/d/your/project/path/design.pen
```
これは Windows 上の `D:\your\project\path\design.pen` に対応し、Pencil と Windows アプリの両方からアクセスできます。

> 💡 **ヒント**：WSL は Windows ドライブを `/mnt/` 以下にマウントします — `C:\` = `/mnt/c/`、`D:\` = `/mnt/d/` など。

### MCP 接続テスト

```powershell
# MCP Server が正常に起動するかテスト
wsl -d Ubuntu -u <ユーザー名> -e bash -c "echo 'test' | timeout 3 /home/<ユーザー名>/pencil-mcp.sh 2>&1"

# 期待される出力：
# [MCP] Starting server in stdio mode
# {"jsonrpc":"2.0","id":null,"error":{"code":-32700,"message":"Parse error"}}
```

## 動作原理

Pencil は Windows 上でネイティブに実行されているわけでは**ありません**。WSL2 内の Linux プロセスとして実行され、複数のブリッジ層を通じて実現しています：

### GUI 表示（WSLg）

WSL2 には [WSLg](https://github.com/microsoft/wslg)（Windows Subsystem for Linux GUI）が内蔵されており、Wayland/X11 を通じて Linux GUI アプリを Windows デスクトップに自動転送します。Pencil のウィンドウはネイティブ Windows アプリのようにデスクトップに表示されますが、実際には Linux プロセスがレンダリングしています。

### AppImage → squashfs 展開

Pencil は AppImage 形式で配布されており、通常は FUSE による仮想ファイルシステムのマウントが必要です。しかし、WSL2 の FUSE は不安定で、マウントポイント（`/tmp/.mount_Pencil*`）が頻繁に切断され、`"Transport endpoint is not connected"` エラーが発生します。

解決策：AppImage の squashfs コンテンツを直接展開（`--appimage-extract`）し、FUSE を完全にバイパス。展開された `squashfs-root/` ディレクトリには完全なアプリケーションが含まれ、直接実行できます。

### MCP プロトコルブリッジ

Pencil の MCP Server はスタンドアロンバイナリ（`mcp-server-linux-x64`）で、WebSocket（localhost）を通じて Pencil GUI と通信し、stdio ベースの MCP インターフェースを公開します。

ブリッジチェーン：

```
Warp (Windows)
  │
  ├─ stdio ─→ wsl.exe ─→ pencil-mcp.sh ─→ mcp-server-linux-x64
  │                                              │
  │                                         WebSocket (localhost)
  │                                              │
  └─ WSLg ──── X11/Wayland ──────────────── Pencil GUI
```

1. **Warp** が stdio を通じて `wsl.exe` に MCP リクエストを送信
2. **wsl.exe** が stdin/stdout を Linux の `pencil-mcp.sh` スクリプトに転送
3. **MCP Server** がリクエストを処理し、ローカル WebSocket で Pencil GUI と通信
4. **Pencil GUI** が WSLg でレンダリングされ、Windows デスクトップに表示

### プロキシ処理

WSL2 は NAT ネットワークで動作し、Windows ホストの `localhost` にアクセスできません。プロキシトラフィックは WSL 仮想ネットワーク上の Windows ホストの実際の IP（例：`172.25.176.1`）にルーティングする必要があります。両方のスクリプトで `http_proxy` / `https_proxy` をこのアドレスに設定しています。

## ライセンス

MIT
