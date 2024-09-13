#!/bin/bash

# 定义文件路径和下载 URL
SETUP_SCRIPT_LOCAL="setup_cloudflarest.sh"
SETUP_SCRIPT_URL="https://mirror.ghproxy.com/https://raw.githubusercontent.com/GuangYu-yu/opw-cloudflare/main/setup_cloudflarest.sh"

RESOLVE_SCRIPT_LOCAL="cf.sh"
RESOLVE_SCRIPT_URL="https://mirror.ghproxy.com/https://raw.githubusercontent.com/GuangYu-yu/opw-cloudflare/main/cf.sh"

CFOPW_SCRIPT_LOCAL="cfopw.sh"
CFOPW_SCRIPT_URL="https://mirror.ghproxy.com/https://raw.githubusercontent.com/GuangYu-yu/opw-cloudflare/main/cfopw.sh"

# 删除旧文件
echo "正在删除旧的脚本文件..."
rm -f "$SETUP_SCRIPT_LOCAL" "$RESOLVE_SCRIPT_LOCAL" "$CFOPW_SCRIPT_LOCAL"

# 下载 setup_cloudflarest.sh 并赋予执行权限
MAX_RETRIES=3
RETRY_DELAY=5
retry_count=0

while [ $retry_count -lt $MAX_RETRIES ]; do
  echo "获取 setup_cloudflarest.sh..."
  if curl -ksSL -o "$SETUP_SCRIPT_LOCAL" "$SETUP_SCRIPT_URL"; then
    echo "setup_cloudflarest.sh 已更新。"
    chmod +x "$SETUP_SCRIPT_LOCAL"
    break
  else
    echo "下载 setup_cloudflarest.sh 失败。"
    retry_count=$((retry_count + 1))
    sleep $RETRY_DELAY
  fi
done

if [ $retry_count -eq $MAX_RETRIES ]; then
  echo "多次尝试下载 setup_cloudflarest.sh 失败，退出。"
  exit 1
fi

# 下载 cf.sh 并赋予执行权限
retry_count=0

while [ $retry_count -lt $MAX_RETRIES ]; do
  echo "获取 cf.sh..."
  if curl -ksSL -o "$RESOLVE_SCRIPT_LOCAL" "$RESOLVE_SCRIPT_URL"; then
    echo "cf.sh 已更新。"
    chmod +x "$RESOLVE_SCRIPT_LOCAL"
    break
  else
    echo "下载 cf.sh 失败。"
    retry_count=$((retry_count + 1))
    sleep $RETRY_DELAY
  fi
done

if [ $retry_count -eq $MAX_RETRIES ]; then
  echo "多次尝试下载 cf.sh 失败，退出。"
  exit 1
fi

# 下载 cfopw.sh
retry_count=0

while [ $retry_count -lt $MAX_RETRIES ]; do
  echo "获取 cfopw.sh..."
  if curl -ksSL -o "$CFOPW_SCRIPT_LOCAL" "$CFOPW_SCRIPT_URL"; then
    echo "cfopw.sh 已更新。"
    break
  else
    echo "下载 cfopw.sh 失败。"
    retry_count=$((retry_count + 1))
    sleep $RETRY_DELAY
  fi
done

if [ $retry_count -eq $MAX_RETRIES ]; then
  echo "多次尝试下载 cfopw.sh 失败，退出。"
  exit 1
fi

# 执行 setup_cloudflarest.sh
echo "正在执行 setup_cloudflarest.sh..."
if ./"$SETUP_SCRIPT_LOCAL"; then
  echo "setup_cloudflarest.sh 执行完成。"
else
  echo "执行 setup_cloudflarest.sh 失败。"
  exit 1
fi

# 执行 cf.sh
echo "正在执行 cf.sh..."
if ./"$RESOLVE_SCRIPT_LOCAL"; then
  echo "cf.sh 执行完成。"
else
  echo "执行 cf.sh 失败。"
  exit 1
fi
