# Pencil WSL Bridge

在 Windows 上通过 WSL 运行 Pencil，并桥接 MCP 协议到 Warp 终端。

## 背景

[Pencil](https://pencil.evolany.com/) 是一款优秀的设计工具，但官方仅提供 Linux 版本。本项目通过 WSL 实现在 Windows 环境下运行 Pencil，并提供 MCP Server 桥接方案。

## 解决的问题

1. **代理问题** - WSL 无法访问 `localhost` 代理，改用 Windows 主机 IP
2. **FUSE 挂载问题** - AppImage 依赖的 FUSE 在 WSL 中不稳定，通过提取 squashfs 解决

## 安装

### 1. 前置要求

- Windows 10/11 + WSL2
- Ubuntu (WSL)
- 代理软件（如 Clash）监听在 `7897` 端口

### 2. 在 WSL Ubuntu 中安装

```bash
# 下载 Pencil AppImage
wget https://github.com/nicepkg/pencil/releases/latest/download/Pencil-linux-x86_64.AppImage

# 提取 squashfs（避免 FUSE 问题）
chmod +x Pencil-linux-x86_64.AppImage
./Pencil-linux-x86_64.AppImage --appimage-extract
mv squashfs-root ~/squashfs-root

# 复制启动脚本
cp scripts/start-pencil.sh ~/
cp scripts/pencil-mcp.sh ~/
chmod +x ~/start-pencil.sh ~/pencil-mcp.sh
```

### 3. 配置代理 IP

获取 Windows 主机 IP：
```powershell
(Get-NetIPAddress -InterfaceAlias "vEthernet (WSL*)" -AddressFamily IPv4).IPAddress
```

编辑脚本中的代理地址（替换 `172.25.176.1` 为你的 IP）。

### 4. Windows 桌面快捷方式

将 `windows/启动Pencil.bat` 和 `windows/启动Pencil.ps1` 复制到桌面。

## MCP 配置（Warp）

| 字段 | 值 |
|-----|-----|
| 名称 | `Pencil` |
| 类型 | `stdio` |
| 命令 | `wsl` |
| 参数 | `-d Ubuntu -u <用户名> -e /home/<用户名>/pencil-mcp.sh` |

## 架构

```
Warp (Windows) → WSL → pencil-mcp.sh → Pencil MCP Server → Pencil GUI
```

## License

MIT
