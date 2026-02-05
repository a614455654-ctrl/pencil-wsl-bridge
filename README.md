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

## Installation

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

### Test MCP Connection

```powershell
# Test if MCP Server starts correctly
wsl -d Ubuntu -u <username> -e bash -c "echo 'test' | timeout 3 /home/<username>/pencil-mcp.sh 2>&1"

# Expected output:
# [MCP] Starting server in stdio mode
# {"jsonrpc":"2.0","id":null,"error":{"code":-32700,"message":"Parse error"}}
```

## Architecture

```
Warp (Windows) → WSL → pencil-mcp.sh → Pencil MCP Server → Pencil GUI
```

## License

MIT
