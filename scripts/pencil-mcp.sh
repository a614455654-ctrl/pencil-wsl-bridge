#!/bin/bash
# Pencil MCP Server 桥接脚本

# 配置代理（替换为你的 Windows 主机 IP）
export http_proxy=http://172.25.176.1:7897
export https_proxy=http://172.25.176.1:7897
export all_proxy=http://172.25.176.1:7897

exec ~/squashfs-root/resources/app.asar.unpacked/out/mcp-server-linux-x64 -app desktop
