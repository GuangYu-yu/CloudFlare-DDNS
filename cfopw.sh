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

# 检测 setup_cloudflarest.sh 是否有更新
echo "正在检查 setup_cloudflarest.sh 是否有更新..."
if curl -s -z "$SETUP_SCRIPT_LOCAL" -o "$SETUP_SCRIPT_LOCAL" "$SETUP_SCRIPT_URL"; then
  echo "setup_cloudflarest.sh 已经是最新版本。"
else
  echo "已更新 setup_cloudflarest.sh。"
fi

# 下载 resolve_cloudflare.sh 并赋予执行权限
echo "正在下载 resolve_cloudflare.sh..."
curl -ksSL "$RESOLVE_SCRIPT_URL" -o "$RESOLVE_SCRIPT_LOCAL"
chmod +x "$RESOLVE_SCRIPT_LOCAL"

# 提示用户 resolve_cloudflare.sh 已经准备好，可以执行
echo "resolve_cloudflare.sh 已经下载完成并赋予执行权限。"
echo "你可以通过 './$RESOLVE_SCRIPT_LOCAL' 来执行解析。"

# 提示用户 cfopw.sh 自身已经更新
if curl -s -z "$CFOPW_SCRIPT_LOCAL" -o "$CFOPW_SCRIPT_LOCAL" "$CFOPW_SCRIPT_URL"; then
  echo "cfopw.sh 已经是最新版本。"
else
  echo "cfopw.sh 已更新。"
fi

# 执行 resolve_cloudflare.sh
echo "正在执行 resolve_cloudflare.sh..."
./"$RESOLVE_SCRIPT_LOCAL"
