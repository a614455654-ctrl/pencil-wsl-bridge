#!/usr/bin/env pwsh
# Pencil WSL Bridge - One-click Installer
# Usage: irm https://raw.githubusercontent.com/a614455654-ctrl/pencil-wsl-bridge/main/install.ps1 | iex

$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "Pencil WSL Bridge Installer"

function Write-Step { param([string]$msg) Write-Host "`n[$script:step] $msg" -ForegroundColor Cyan; $script:step++ }
function Write-Ok { param([string]$msg) Write-Host "  OK: $msg" -ForegroundColor Green }
function Write-Err { param([string]$msg) Write-Host "  ERROR: $msg" -ForegroundColor Red }
$script:step = 1

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  Pencil WSL Bridge Installer" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

# ── 1. Check WSL ──
Write-Step "Checking WSL2..."
try {
    $wslList = wsl -l -q 2>$null
    if (-not $wslList) { throw "no distro" }
    Write-Ok "WSL2 is available"
} catch {
    Write-Err "WSL2 is not installed or no distro found."
    Write-Host "  Install WSL2: wsl --install" -ForegroundColor Yellow
    exit 1
}

# ── 2. Select distro ──
Write-Step "Detecting WSL distros..."
$distros = (wsl -l -q 2>$null) | Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_.Trim() -replace '\x00', '' } | Where-Object { $_ }
if ($distros -is [string]) { $distros = @($distros) }

if ($distros.Count -eq 1) {
    $distro = $distros[0]
    Write-Ok "Using distro: $distro"
} else {
    Write-Host "  Available distros:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $distros.Count; $i++) {
        Write-Host "    [$($i+1)] $($distros[$i])"
    }
    $choice = Read-Host "  Select distro (1-$($distros.Count))"
    $distro = $distros[[int]$choice - 1]
    Write-Ok "Using distro: $distro"
}

# ── 3. Detect WSL user ──
Write-Step "Detecting WSL default user..."
$wslUser = (wsl -d $distro -- whoami 2>$null).Trim() -replace '\x00', ''
if ($wslUser -eq "root") {
    $wslUser = (wsl -d $distro -- bash -c "getent passwd 1000 | cut -d: -f1" 2>$null).Trim() -replace '\x00', ''
}
if (-not $wslUser) { $wslUser = "root" }
Write-Ok "WSL user: $wslUser"

$wslHome = if ($wslUser -eq "root") { "/root" } else { "/home/$wslUser" }

# ── 4. Get Windows host IP ──
Write-Step "Detecting Windows host IP for WSL..."
$hostIP = (wsl -d $distro -u $wslUser -- bash -c "cat /etc/resolv.conf | grep nameserver | awk '{print `$2}'" 2>$null).Trim() -replace '\x00', ''
if (-not $hostIP) {
    $hostIP = "172.25.176.1"
    Write-Host "  Could not detect, using default: $hostIP" -ForegroundColor Yellow
} else {
    Write-Ok "Host IP: $hostIP"
}

# ── 5. Check proxy port ──
Write-Step "Proxy configuration..."
$proxyPort = Read-Host "  Enter proxy port (default: 7897, enter 'none' to skip proxy)"
if ($proxyPort -eq "none" -or $proxyPort -eq "no") {
    $useProxy = $false
    Write-Ok "Proxy disabled"
} else {
    $useProxy = $true
    if (-not $proxyPort) { $proxyPort = "7897" }
    Write-Ok "Proxy: http://${hostIP}:${proxyPort}"
}

# ── 6. Download and install Pencil ──
Write-Step "Installing Pencil in WSL..."

$proxyEnv = ""
if ($useProxy) {
    $proxyEnv = "export http_proxy=http://${hostIP}:${proxyPort}; export https_proxy=http://${hostIP}:${proxyPort}; export all_proxy=http://${hostIP}:${proxyPort};"
}

$installScript = @"
set -e
$proxyEnv

# Check if already installed
if [ -d "$wslHome/squashfs-root/pencil" ]; then
    echo "Pencil is already installed. Reinstall? (y/n)"
    read -r answer
    if [ "`$answer" != "y" ]; then
        echo "Skipping installation."
        exit 0
    fi
    rm -rf "$wslHome/squashfs-root"
fi

cd /tmp
echo "Downloading Pencil AppImage..."
wget -q --show-progress https://github.com/nicepkg/pencil/releases/latest/download/Pencil-linux-x86_64.AppImage -O pencil.AppImage

echo "Extracting squashfs..."
chmod +x pencil.AppImage
./pencil.AppImage --appimage-extract > /dev/null 2>&1
rm -rf "$wslHome/squashfs-root"
mv squashfs-root "$wslHome/squashfs-root"
rm -f pencil.AppImage

echo "Pencil installed to $wslHome/squashfs-root"
"@

wsl -d $distro -u $wslUser -- bash -c $installScript
Write-Ok "Pencil installed"

# ── 7. Create scripts in WSL ──
Write-Step "Creating startup scripts..."

$proxyBlock = ""
if ($useProxy) {
    $proxyBlock = @"
export http_proxy=http://${hostIP}:${proxyPort}
export https_proxy=http://${hostIP}:${proxyPort}
export all_proxy=http://${hostIP}:${proxyPort}
"@
}

$startScript = @"
#!/bin/bash
$proxyBlock
cd ~/squashfs-root
./pencil --no-sandbox "`$@"
"@

$mcpScript = @"
#!/bin/bash
$proxyBlock
exec ~/squashfs-root/resources/app.asar.unpacked/out/mcp-server-linux-x64 -app desktop
"@

wsl -d $distro -u $wslUser -- bash -c "cat > $wslHome/start-pencil.sh << 'SCRIPT_EOF'
$startScript
SCRIPT_EOF
chmod +x $wslHome/start-pencil.sh"

wsl -d $distro -u $wslUser -- bash -c "cat > $wslHome/pencil-mcp.sh << 'SCRIPT_EOF'
$mcpScript
SCRIPT_EOF
chmod +x $wslHome/pencil-mcp.sh"

Write-Ok "Scripts created"

# ── 8. Create Windows desktop shortcut ──
Write-Step "Creating desktop shortcut..."
$desktop = [Environment]::GetFolderPath("Desktop")

$ps1Content = @"
`$Host.UI.RawUI.WindowTitle = "Pencil Launcher"
Write-Host "Checking Pencil process..." -ForegroundColor Cyan
`$killResult = wsl -d $distro -u $wslUser -e bash -c "pkill -f 'pencil --no-sandbox' 2>/dev/null && echo 'killed' || echo 'none'"
if (`$killResult -match "killed") {
    Write-Host "Terminated old Pencil process" -ForegroundColor Yellow
    Start-Sleep -Seconds 1
} else {
    Write-Host "No running Pencil process found" -ForegroundColor Green
}
Write-Host "Starting Pencil..." -ForegroundColor Cyan
Start-Process wsl -ArgumentList "-d", "$distro", "-u", "$wslUser", "-e", "$wslHome/start-pencil.sh" -WindowStyle Hidden
Write-Host "Pencil launched!" -ForegroundColor Green
Start-Sleep -Seconds 2
"@

$batContent = @"
@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0Launch Pencil.ps1"
"@

$ps1Content | Out-File -FilePath "$desktop\Launch Pencil.ps1" -Encoding UTF8
$batContent | Out-File -FilePath "$desktop\Launch Pencil.bat" -Encoding ASCII
Write-Ok "Desktop shortcut created: Launch Pencil.bat"

# ── 9. Create MCP .cmd wrapper ──
Write-Step "Creating MCP wrapper..."
$cmdPath = "$env:USERPROFILE\pencil-mcp.cmd"
$cmdContent = "@echo off`r`nwsl -d $distro -u $wslUser -e $wslHome/pencil-mcp.sh 2>nul"
$cmdContent | Out-File -FilePath $cmdPath -Encoding ASCII
Write-Ok "MCP wrapper created: $cmdPath"

# ── 10. Done ──
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Quick Start:" -ForegroundColor Cyan
Write-Host "  1. Double-click 'Launch Pencil.bat' on desktop"
Write-Host "  2. Wait for Pencil to fully load"
Write-Host ""
Write-Host "MCP Configuration (for Warp / other AI tools):" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Name:    Pencil"
Write-Host "  Type:    stdio"
Write-Host "  Command: $cmdPath"
Write-Host "  Args:    (empty)"
Write-Host ""
Write-Host "Or JSON format:" -ForegroundColor Yellow
Write-Host @"
  {
    "Pencil": {
      "command": "$($cmdPath -replace '\\', '\\')",
      "args": [],
      "env": {},
      "start_on_launch": true
    }
  }
"@
Write-Host ""
Write-Host "GitHub: https://github.com/a614455654-ctrl/pencil-wsl-bridge" -ForegroundColor DarkGray
Write-Host ""
Read-Host "Press Enter to exit"
