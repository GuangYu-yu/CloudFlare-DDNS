#!/bin/bash

# 定义 setup_cloudflarest.sh 文件的 URL 和本地路径
SETUP_SCRIPT_URL="https://mirror.ghproxy.com/https://raw.githubusercontent.com/GuangYu-yu/opw-cloudflare/main/setup_cloudflarest.sh"
SETUP_SCRIPT_LOCAL="setup_cloudflarest.sh"

# 定义 resolve_cloudflare.sh 文件的 URL 和本地路径
RESOLVE_SCRIPT_URL="https://mirror.ghproxy.com/https://raw.githubusercontent.com/GuangYu-yu/opw-cloudflare/main/resolve_cloudflare.sh"
RESOLVE_SCRIPT_LOCAL="resolve_cloudflare.sh"

# 定义 cfopw.sh 文件的 URL 和本地路径
CFOPW_SCRIPT_URL="https://mirror.ghproxy.com/https://raw.githubusercontent.com/GuangYu-yu/opw-cloudflare/main/cfopw.sh"
CFOPW_SCRIPT_LOCAL="cfopw.sh"

# 检查并更新 setup_cloudflarest.sh 文件
echo "检查并更新 setup_cloudflarest.sh 文件..."
if curl -s -z "$SETUP_SCRIPT_LOCAL" -o "$SETUP_SCRIPT_LOCAL" "$SETUP_SCRIPT_URL"; then
  echo "setup_cloudflarest.sh 文件已经是最新版本。"
else
  echo "setup_cloudflarest.sh 文件已更新。"
fi

# 检查并更新 resolve_cloudflare.sh 文件
echo "检查并更新 resolve_cloudflare.sh 文件..."
if curl -s -z "$RESOLVE_SCRIPT_LOCAL" -o "$RESOLVE_SCRIPT_LOCAL" "$RESOLVE_SCRIPT_URL"; then
  echo "resolve_cloudflare.sh 文件已经是最新版本。"
else
  echo "resolve_cloudflare.sh 文件已更新。"
  chmod +x "$RESOLVE_SCRIPT_LOCAL"
fi

# 检查并更新 cfopw.sh 文件
echo "检查并更新 cfopw.sh 文件..."
if curl -s -z "$CFOPW_SCRIPT_LOCAL" -o "$CFOPW_SCRIPT_LOCAL" "$CFOPW_SCRIPT_URL"; then
  echo "cfopw.sh 文件已经是最新版本。"
else
  echo "cfopw.sh 文件已更新。"
fi

# 执行 resolve_cloudflare.sh 文件
echo "正在执行 resolve_cloudflare.sh 文件..."
if ./"$RESOLVE_SCRIPT_LOCAL"; then
  echo "resolve_cloudflare.sh 文件执行完成。"
else
  echo "执行 resolve_cloudflare.sh 文件失败。"
  exit 1
fi
