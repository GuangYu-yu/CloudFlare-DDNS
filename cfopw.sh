#!/bin/bash

# 定义脚本的 URL 和本地路径
SETUP_SCRIPT_URL="https://mirror.ghproxy.com/https://raw.githubusercontent.com/GuangYu-yu/opw-cloudflare/main/setup_cloudflarest.sh"
SETUP_SCRIPT_LOCAL="setup_cloudflarest.sh"

RESOLVE_SCRIPT_URL="https://mirror.ghproxy.com/https://raw.githubusercontent.com/GuangYu-yu/opw-cloudflare/main/resolve_cloudflare.sh"
RESOLVE_SCRIPT_LOCAL="resolve_cloudflare.sh"

CFOPW_SCRIPT_URL="https://mirror.ghproxy.com/https://raw.githubusercontent.com/GuangYu-yu/opw-cloudflare/main/cfopw.sh"
CFOPW_SCRIPT_LOCAL="cfopw.sh"

# 删除已存在的脚本
echo "删除已存在的脚本..."
rm -f "$SETUP_SCRIPT_LOCAL" "$RESOLVE_SCRIPT_LOCAL" "$CFOPW_SCRIPT_LOCAL"

# 下载 setup_cloudflarest.sh 文件
echo "下载 setup_cloudflarest.sh 文件..."
curl -ksSL "$SETUP_SCRIPT_URL" -o "$SETUP_SCRIPT_LOCAL"
echo "setup_cloudflarest.sh 文件下载完成。"

# 下载 resolve_cloudflare.sh 文件并赋予执行权限
echo "下载 resolve_cloudflare.sh 文件..."
curl -ksSL "$RESOLVE_SCRIPT_URL" -o "$RESOLVE_SCRIPT_LOCAL"
chmod +x "$RESOLVE_SCRIPT_LOCAL"
echo "resolve_cloudflare.sh 文件下载完成并赋予执行权限。"

# 下载 cfopw.sh 文件
echo "下载 cfopw.sh 文件..."
curl -ksSL "$CFOPW_SCRIPT_URL" -o "$CFOPW_SCRIPT_LOCAL"
echo "cfopw.sh 文件下载完成。"

# 执行 resolve_cloudflare.sh 文件
echo "正在执行 resolve_cloudflare.sh 文件..."
if ./"$RESOLVE_SCRIPT_LOCAL"; then
  echo "resolve_cloudflare.sh 文件执行完成。"
else
  echo "执行 resolve_cloudflare.sh 文件失败。"
  exit 1
fi
