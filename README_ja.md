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

## インストール

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

### MCP 接続テスト

```powershell
# MCP Server が正常に起動するかテスト
wsl -d Ubuntu -u <ユーザー名> -e bash -c "echo 'test' | timeout 3 /home/<ユーザー名>/pencil-mcp.sh 2>&1"

# 期待される出力：
# [MCP] Starting server in stdio mode
# {"jsonrpc":"2.0","id":null,"error":{"code":-32700,"message":"Parse error"}}
```

## アーキテクチャ

```
Warp (Windows) → WSL → pencil-mcp.sh → Pencil MCP Server → Pencil GUI
```

## ライセンス

MIT
