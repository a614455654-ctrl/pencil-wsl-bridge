@echo off
REM Pencil MCP Server 包装脚本
REM 用于抑制 WSL stderr 输出，避免干扰 MCP stdio 通信
REM 使用前请将 <用户名> 替换为你的 WSL 用户名

wsl -d Ubuntu -u sunset -e /home/sunset/pencil-mcp.sh 2>nul
