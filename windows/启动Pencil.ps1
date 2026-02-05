#!/usr/bin/env pwsh
# Pencil 启动脚本 - 自动检测并重启

$Host.UI.RawUI.WindowTitle = "Pencil Launcher"

Write-Host "正在检测 Pencil 进程..." -ForegroundColor Cyan

# 检测并杀掉WSL中的Pencil进程
$killResult = wsl -d Ubuntu -e bash -c "pkill -f 'pencil --no-sandbox' 2>/dev/null && echo 'killed' || echo 'none'"

if ($killResult -match "killed") {
    Write-Host "已终止旧的 Pencil 进程" -ForegroundColor Yellow
    Start-Sleep -Seconds 1
} else {
    Write-Host "没有发现运行中的 Pencil 进程" -ForegroundColor Green
}

Write-Host "正在启动 Pencil..." -ForegroundColor Cyan

# 后台启动Pencil（替换 <用户名> 为你的 WSL 用户名）
Start-Process wsl -ArgumentList "-d", "Ubuntu", "-e", "~/start-pencil.sh" -WindowStyle Hidden

Write-Host "Pencil 已在后台启动!" -ForegroundColor Green
Start-Sleep -Seconds 2
