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

## 一键安装

在 PowerShell 中运行：
```powershell
irm https://raw.githubusercontent.com/a614455654-ctrl/pencil-wsl-bridge/main/install.ps1 | iex
```

安装程序会自动：
- 检测 WSL 发行版和用户
- 下载并提取 Pencil
- 配置代理设置
- 创建桌面快捷方式和 MCP 包装器
- 输出 AI 工具的 MCP 配置信息

## 手动安装

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

## 工作原理

Pencil **并不是**原生运行在 Windows 上。它作为 Linux 进程运行在 WSL2 内部，通过多层桥接实现：

### GUI 显示（WSLg）

WSL2 内置了 [WSLg](https://github.com/microsoft/wslg)（Windows Subsystem for Linux GUI），它通过 Wayland/X11 自动将 Linux GUI 应用转发到 Windows 桌面。因此 Pencil 的窗口会像原生 Windows 应用一样显示在你的桌面上，但实际上它是由 Linux 进程渲染的。

### AppImage → squashfs 提取

Pencil 以 AppImage 格式发布，正常情况下需要 FUSE 在运行时挂载虚拟文件系统。但 WSL2 中的 FUSE 不可靠——挂载点（`/tmp/.mount_Pencil*`）经常断开连接，报错 `"Transport endpoint is not connected"`。

我们的解决方案：直接提取 AppImage 的 squashfs 内容（`--appimage-extract`），完全绕过 FUSE。提取出的 `squashfs-root/` 目录包含完整应用，可以直接运行。

### MCP 协议桥接

Pencil 的 MCP Server 是一个独立的二进制文件（`mcp-server-linux-x64`），它通过 WebSocket（localhost）与 Pencil GUI 通信，并对外暴露基于 stdio 的 MCP 接口。

桥接链路：

```
Warp (Windows)
  │
  ├─ stdio ─→ wsl.exe ─→ pencil-mcp.sh ─→ mcp-server-linux-x64
  │                                              │
  │                                         WebSocket (localhost)
  │                                              │
  └─ WSLg ──── X11/Wayland ──────────────── Pencil GUI
```

1. **Warp** 通过 stdio 向 `wsl.exe` 发送 MCP 请求
2. **wsl.exe** 将 stdin/stdout 转发到 Linux 中的 `pencil-mcp.sh` 脚本
3. **MCP Server** 处理请求，并通过本地 WebSocket 与 Pencil GUI 通信
4. **Pencil GUI** 通过 WSLg 渲染，显示在 Windows 桌面上

### 代理处理

WSL2 运行在 NAT 网络中，无法访问 Windows 主机的 `localhost`。代理流量必须路由到 Windows 主机在 WSL 虚拟网络上的实际 IP（如 `172.25.176.1`）。两个脚本都配置了 `http_proxy` / `https_proxy` 指向该地址。

## 许可证

MIT
