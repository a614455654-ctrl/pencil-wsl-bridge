# Pencil WSL Bridge

**[English](README.md)** | **[中文](README_zh.md)** | **[日本語](README_ja.md)**

Run [Pencil](https://pencil.evolany.com/) on Windows via WSL and bridge its MCP protocol to Warp terminal.

## Why?

Pencil only provides a Linux build. This project solves that by running it inside WSL and bridging the MCP Server to Windows.

## Problems Solved

1. **Proxy issue** - WSL cannot access `localhost` proxy; uses Windows host IP instead
2. **FUSE mount issue** - AppImage FUSE is unstable in WSL; extract squashfs to run directly
3. **MCP arg format** - MCP Server uses single-dash args `-app` instead of `--app`
4. **WSL stderr interference** - WSL proxy warnings interfere with MCP stdio; suppress via `.cmd` wrapper
5. **File save location** - Ctrl+S saves to the Linux filesystem by default, which is not easily accessible from Windows

## Quick Install

Run this in PowerShell:
```powershell
irm https://raw.githubusercontent.com/a614455654-ctrl/pencil-wsl-bridge/main/install.ps1 | iex
```

The installer will automatically:
- Detect your WSL distro and user
- Download and extract Pencil
- Configure proxy settings
- Create desktop shortcut and MCP wrapper
- Print MCP configuration for your AI tool

## Manual Installation

### Prerequisites

- Windows 10/11 + WSL2
- Ubuntu (WSL)
- Proxy software (e.g. Clash) listening on port `7897`

### 1. Install in WSL Ubuntu

```bash
# Download Pencil AppImage
wget https://github.com/nicepkg/pencil/releases/latest/download/Pencil-linux-x86_64.AppImage

# Extract squashfs (avoids FUSE issues)
chmod +x Pencil-linux-x86_64.AppImage
./Pencil-linux-x86_64.AppImage --appimage-extract
mv squashfs-root ~/squashfs-root

# Copy scripts
cp scripts/start-pencil.sh ~/
cp scripts/pencil-mcp.sh ~/
chmod +x ~/start-pencil.sh ~/pencil-mcp.sh
```

### 2. Configure Proxy IP

Get your Windows host IP:
```powershell
(Get-NetIPAddress -InterfaceAlias "vEthernet (WSL*)" -AddressFamily IPv4).IPAddress
```

Edit the proxy address in both scripts (replace `172.25.176.1` with your IP).

### 3. Desktop Shortcut

Copy `windows/启动Pencil.bat` and `windows/启动Pencil.ps1` to your desktop.

## MCP Configuration (Warp)

### Method 1: .cmd Wrapper (Recommended)

Create `C:\Users\<username>\pencil-mcp.cmd`:
```batch
@echo off
wsl -d Ubuntu -u <username> -e /home/<username>/pencil-mcp.sh 2>nul
```

Warp MCP config:
```json
{
  "Pencil": {
    "command": "C:\\Users\\<username>\\pencil-mcp.cmd",
    "args": [],
    "env": {},
    "start_on_launch": true
  }
}
```

### Method 2: Direct WSL Call

```json
{
  "Pencil": {
    "command": "wsl",
    "args": ["-d", "Ubuntu", "-u", "<username>", "-e", "/home/<username>/pencil-mcp.sh"],
    "env": {},
    "start_on_launch": true
  }
}
```

> ⚠️ If WSL outputs proxy warnings causing `Transport closed` errors, use Method 1.

## Troubleshooting

### Issue 1: Transport closed

**Cause**: WSL stderr output (e.g. proxy warnings) interferes with MCP stdio communication.

**Solution**: Use `.cmd` wrapper script with `2>nul` to suppress stderr.

### Issue 2: WebSocket not connected to app: desktop

**Cause**: MCP Server cannot connect to Pencil GUI.

**Solution**:
1. Make sure Pencil GUI is launched first (double-click `启动Pencil.bat`)
2. Wait for Pencil to fully load before enabling MCP
3. Check if port file exists: `~/.pencil/apps/desktop`

### Issue 3: MCP arg format error

**Cause**: MCP Server uses single-dash args.

**Solution**: Use `-app desktop` instead of `--app desktop`.

### Issue 4: Saved files not found / no save prompt

**Cause**: Pencil runs inside WSL, so Ctrl+S saves files to the Linux filesystem (e.g. `/home/username/...`), which is not directly visible from Windows Explorer.

**Solution**: Use **File → Save As** and save to a Windows path via the WSL mount:
```
/mnt/d/your/project/path/design.pen
```
This maps to `D:\your\project\path\design.pen` on Windows, accessible by both Pencil and Windows applications.

> 💡 **Tip**: WSL mounts Windows drives under `/mnt/` — so `C:\` = `/mnt/c/`, `D:\` = `/mnt/d/`, etc.

### Test MCP Connection

```powershell
# Test if MCP Server starts correctly
wsl -d Ubuntu -u <username> -e bash -c "echo 'test' | timeout 3 /home/<username>/pencil-mcp.sh 2>&1"

# Expected output:
# [MCP] Starting server in stdio mode
# {"jsonrpc":"2.0","id":null,"error":{"code":-32700,"message":"Parse error"}}
```

## How it Works

Pencil does **not** run natively on Windows. It runs as a Linux process inside WSL2, with multiple layers of bridging:

### GUI Display (WSLg)

WSL2 includes [WSLg](https://github.com/microsoft/wslg) (Windows Subsystem for Linux GUI), which automatically forwards Linux GUI applications to the Windows desktop via Wayland/X11. This means Pencil's window appears on your Windows desktop as if it were a native app, but it's actually rendered by a Linux process.

### AppImage → squashfs Extraction

Pencil is distributed as an AppImage, which normally requires FUSE to mount a virtual filesystem at runtime. However, FUSE in WSL2 is unreliable — the mount point (`/tmp/.mount_Pencil*`) frequently disconnects with `"Transport endpoint is not connected"` errors. 

Our solution: extract the AppImage's squashfs contents directly (`--appimage-extract`), bypassing FUSE entirely. The extracted `squashfs-root/` directory contains the full application and can be run directly.

### MCP Protocol Bridging

Pencil's MCP Server is a standalone binary (`mcp-server-linux-x64`) that communicates with the Pencil GUI via WebSocket (localhost) and exposes a stdio-based MCP interface.

The bridging chain:

```
Warp (Windows)
  │
  ├─ stdio ─→ wsl.exe ─→ pencil-mcp.sh ─→ mcp-server-linux-x64
  │                                              │
  │                                         WebSocket (localhost)
  │                                              │
  └─ WSLg ──── X11/Wayland ──────────────── Pencil GUI
```

1. **Warp** sends MCP requests via stdio to `wsl.exe`
2. **wsl.exe** forwards stdin/stdout to the Linux `pencil-mcp.sh` script
3. **MCP Server** processes requests and communicates with Pencil GUI over local WebSocket
4. **Pencil GUI** renders via WSLg, displayed on Windows desktop

### Proxy Handling

WSL2 runs in a NAT network and cannot access `localhost` on the Windows host. Proxy traffic must be routed to the Windows host's actual IP on the WSL virtual network (e.g. `172.25.176.1`). Both scripts configure `http_proxy` / `https_proxy` to point to this address.

## License

MIT
