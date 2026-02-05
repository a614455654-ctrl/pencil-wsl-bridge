#!/bin/bash
# Pencil GUI 启动脚本

# 配置代理（替换为你的 Windows 主机 IP）
export http_proxy=http://172.25.176.1:7897
export https_proxy=http://172.25.176.1:7897
export all_proxy=http://172.25.176.1:7897

cd ~/squashfs-root
./pencil --no-sandbox "$@"
