#!/bin/bash

# 定义文件路径和下载 URL
SETUP_SCRIPT_LOCAL="setup_cloudflarest.sh"
SETUP_SCRIPT_URL="https://mirror.ghproxy.com/https://raw.githubusercontent.com/GuangYu-yu/opw-cloudflare/main/setup_cloudflarest.sh"

RESOLVE_SCRIPT_LOCAL="resolve_cloudflare.sh"
RESOLVE_SCRIPT_URL="https://mirror.ghproxy.com/https://raw.githubusercontent.com/GuangYu-yu/opw-cloudflare/main/resolve_cloudflare.sh"

CFOPW_SCRIPT_LOCAL="cfopw.sh"
CFOPW_SCRIPT_URL="https://mirror.ghproxy.com/https://raw.githubusercontent.com/GuangYu-yu/opw-cloudflare/main/cfopw.sh"

# 删除旧文件
echo "正在删除旧的脚本文件..."
rm -f "$SETUP_SCRIPT_LOCAL" "$RESOLVE_SCRIPT_LOCAL" "$CFOPW_SCRIPT_LOCAL"

# 下载并更新 setup_cloudflarest.sh
echo "检查并更新 setup_cloudflarest.sh..."
if curl -ksSL -o "$SETUP_SCRIPT_LOCAL" "$SETUP_SCRIPT_URL"; then
  echo "setup_cloudflarest.sh 已更新。"
else
  echo "下载 setup_cloudflarest.sh 失败。"
  exit 1
fi

# 下载并更新 resolve_cloudflare.sh 并赋予执行权限
echo "检查并更新 resolve_cloudflare.sh..."
if curl -ksSL -o "$RESOLVE_SCRIPT_LOCAL" "$RESOLVE_SCRIPT_URL"; then
  echo "resolve_cloudflare.sh 已更新。"
  chmod +x "$RESOLVE_SCRIPT_LOCAL"
else
  echo "下载 resolve_cloudflare.sh 失败。"
  exit 1
fi

# 下载并更新 cfopw.sh
echo "检查并更新 cfopw.sh..."
if curl -ksSL -o "$CFOPW_SCRIPT_LOCAL" "$CFOPW_SCRIPT_URL"; then
  echo "cfopw.sh 已更新。"
else
  echo "下载 cfopw.sh 失败。"
  exit 1
fi

# 执行 resolve_cloudflare.sh
echo "正在执行 resolve_cloudflare.sh..."
if ./"$RESOLVE_SCRIPT_LOCAL"; then
  echo "resolve_cloudflare.sh 执行完成。"
else
  echo "执行 resolve_cloudflare.sh 失败。"
  exit 1
fi
