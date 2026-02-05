# Pencil WSL Bridge

**[English](README.md)** | **[中文](README_zh.md)** | **[日本語](README_ja.md)**

在 Windows 上通过 WSL 运行 [Pencil](https://pencil.evolany.com/)，并桥接 MCP 协议到 Warp 终端。

## 为什么需要这个项目？

Pencil 官方仅提供 Linux 版本。本项目通过 WSL 运行 Pencil，并将 MCP Server 桥接到 Windows 侧。

## 解决的问题

1. **代理问题** - WSL 无法访问 `localhost` 代理，改用 Windows 主机 IP
2. **FUSE 挂载问题** - AppImage 的 FUSE 在 WSL 中不稳定，通过提取 squashfs 直接运行
3. **MCP 参数格式** - MCP Server 使用单横线参数 `-app` 而非 `--app`
4. **WSL stderr 干扰** - WSL 代理警告会干扰 MCP stdio 通信，需通过 `.cmd` 包装抑制

## 安装

### 前置要求

- Windows 10/11 + WSL2
- Ubuntu (WSL)
- 代理软件（如 Clash）监听在 `7897` 端口

### 1. 在 WSL Ubuntu 中安装

```bash
# 下载 Pencil AppImage
wget https://github.com/nicepkg/pencil/releases/latest/download/Pencil-linux-x86_64.AppImage

# 提取 squashfs（避免 FUSE 问题）
chmod +x Pencil-linux-x86_64.AppImage
./Pencil-linux-x86_64.AppImage --appimage-extract
mv squashfs-root ~/squashfs-root

# 复制脚本
cp scripts/start-pencil.sh ~/
cp scripts/pencil-mcp.sh ~/
chmod +x ~/start-pencil.sh ~/pencil-mcp.sh
```

### 2. 配置代理 IP

获取 Windows 主机 IP：
```powershell
(Get-NetIPAddress -InterfaceAlias "vEthernet (WSL*)" -AddressFamily IPv4).IPAddress
```

编辑两个脚本中的代理地址（将 `172.25.176.1` 替换为你的 IP）。

### 3. 桌面快捷方式

将 `windows/启动Pencil.bat` 和 `windows/启动Pencil.ps1` 复制到桌面即可。

## MCP 配置（Warp）

### 方法一：使用 .cmd 包装（推荐）

创建 `C:\Users\<用户名>\pencil-mcp.cmd`：
```batch
@echo off
wsl -d Ubuntu -u <用户名> -e /home/<用户名>/pencil-mcp.sh 2>nul
```

Warp MCP 配置：
```json
{
  "Pencil": {
    "command": "C:\\Users\\<用户名>\\pencil-mcp.cmd",
    "args": [],
    "env": {},
    "start_on_launch": true
  }
}
```

### 方法二：直接调用 WSL

```json
{
  "Pencil": {
    "command": "wsl",
    "args": ["-d", "Ubuntu", "-u", "<用户名>", "-e", "/home/<用户名>/pencil-mcp.sh"],
    "env": {},
    "start_on_launch": true
  }
}
```

> ⚠️ 如果 WSL 输出代理警告导致 `Transport closed` 错误，请使用方法一。

## 故障排除

### 问题 1：Transport closed

**原因**：WSL 的 stderr 输出（如代理警告）干扰了 MCP 的 stdio 通信。

**解决**：使用 `.cmd` 包装脚本，添加 `2>nul` 抑制 stderr。

### 问题 2：WebSocket not connected to app: desktop

**原因**：MCP Server 无法连接到 Pencil GUI。

**解决**：
1. 确保先启动 Pencil GUI（双击 `启动Pencil.bat`）
2. 等待 Pencil 完全加载后再启用 MCP
3. 检查端口文件是否存在：`~/.pencil/apps/desktop`

### 问题 3：MCP 参数格式错误

**原因**：MCP Server 使用单横线参数。

**解决**：使用 `-app desktop` 而非 `--app desktop`。

### 测试 MCP 连接

```powershell
# 测试 MCP Server 是否正常启动
wsl -d Ubuntu -u <用户名> -e bash -c "echo 'test' | timeout 3 /home/<用户名>/pencil-mcp.sh 2>&1"

# 预期输出：
# [MCP] Starting server in stdio mode
# {"jsonrpc":"2.0","id":null,"error":{"code":-32700,"message":"Parse error"}}
```

## 架构

```
Warp (Windows) → WSL → pencil-mcp.sh → Pencil MCP Server → Pencil GUI
```

## 许可证

MIT
