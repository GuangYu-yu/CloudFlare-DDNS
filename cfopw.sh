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

# 定义下载脚本的函数
download_script() {
    local script_local=$1
    local script_url=$2
    local script_name=$3

    MAX_RETRIES=3
    RETRY_DELAY=5
    retry_count=0

    while [ $retry_count -lt $MAX_RETRIES ]; do
        echo "获取 $script_name..."
        if curl -ksSL -o "$script_local" "$script_url"; then
            echo "$script_name 已更新。"
            chmod +x "$script_local"
            break
        else
            echo "下载 $script_name 失败。"
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $MAX_RETRIES ]; then
                echo "将在 $RETRY_DELAY 秒后重试..."
                sleep $RETRY_DELAY
            else
                echo "重试次数已达上限，退出。"
                exit 1
            fi
        fi
    done
}

# 定义执行脚本的函数
execute_script() {
    local script_local=$1
    local script_name=$2

    echo "正在执行 $script_name..."
    if ./"$script_local"; then
        echo "$script_name 执行完成。"
    else
        echo "执行 $script_name 失败。"
        exit 1
    fi
}

# 下载 setup_cloudflarest.sh
download_script "$SETUP_SCRIPT_LOCAL" "$SETUP_SCRIPT_URL" "setup_cloudflarest.sh"

# 下载 cf.sh
download_script "$RESOLVE_SCRIPT_LOCAL" "$RESOLVE_SCRIPT_URL" "cf.sh"

# 下载 cfopw.sh
download_script "$CFOPW_SCRIPT_LOCAL" "$CFOPW_SCRIPT_URL" "cfopw.sh"

# 执行 setup_cloudflarest.sh
execute_script "$SETUP_SCRIPT_LOCAL" "setup_cloudflarest.sh"

# 执行 cf.sh
execute_script "$RESOLVE_SCRIPT_LOCAL" "cf.sh"
