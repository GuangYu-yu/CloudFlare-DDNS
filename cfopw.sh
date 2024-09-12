#!/bin/bash

# 定义脚本的 URL 和本地路径
SETUP_SCRIPT_URL="https://mirror.ghproxy.com/https://raw.githubusercontent.com/GuangYu-yu/opw-cloudflare/main/setup_cloudflarest.sh"
SETUP_SCRIPT_LOCAL="setup_cloudflarest.sh"

RESOLVE_SCRIPT_URL="https://mirror.ghproxy.com/https://raw.githubusercontent.com/GuangYu-yu/opw-cloudflare/main/resolve_cloudflare.sh"
RESOLVE_SCRIPT_LOCAL="resolve_cloudflare.sh"

CFOPW_SCRIPT_URL="https://mirror.ghproxy.com/https://raw.githubusercontent.com/GuangYu-yu/opw-cloudflare/main/cfopw.sh"
CFOPW_SCRIPT_LOCAL="cfopw.sh"

# 更新 setup_cloudflarest.sh
echo "正在检查 setup_cloudflarest.sh 是否有更新..."
curl -s -z "$SETUP_SCRIPT_LOCAL" -o "$SETUP_SCRIPT_LOCAL" "$SETUP_SCRIPT_URL"

# 更新 resolve_cloudflare.sh 并赋予执行权限
echo "正在下载 resolve_cloudflare.sh..."
curl -ksSL "$RESOLVE_SCRIPT_URL" -o "$RESOLVE_SCRIPT_LOCAL"
chmod +x "$RESOLVE_SCRIPT_LOCAL"

# 更新 cfopw.sh
echo "正在检查 cfopw.sh 是否有更新..."
curl -s -z "$CFOPW_SCRIPT_LOCAL" -o "$CFOPW_SCRIPT_LOCAL" "$CFOPW_SCRIPT_URL"

# 执行 resolve_cloudflare.sh
echo "正在执行 resolve_cloudflare.sh..."
if ./"$RESOLVE_SCRIPT_LOCAL"; then
  echo "resolve_cloudflare.sh 执行完成。"
else
  echo "执行 resolve_cloudflare.sh 失败。"
  exit 1
fi
