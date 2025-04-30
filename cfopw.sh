#!/bin/bash

# 定义文件路径和API URL
SETUP_SCRIPT_LOCAL="setup_cloudflarest.sh"
SETUP_SCRIPT_API="https://ghfast.top/https://github.com/GuangYu-yu/opw-cloudflare/raw/refs/heads/main/setup_cloudflarest.sh"

RESOLVE_SCRIPT_LOCAL="cf"
RESOLVE_SCRIPT_API="https://ghfast.top/https://github.com/GuangYu-yu/opw-cloudflare/raw/refs/heads/main/cf"

START_DDNS_LOCAL="start_ddns.sh"
START_DDNS_API="https://ghfast.top/https://github.com/GuangYu-yu/opw-cloudflare/raw/refs/heads/main/start_ddns.sh"

CF_PUSH_LOCAL="cf_push.sh"
CF_PUSH_API="https://ghfast.top/https://github.com/GuangYu-yu/opw-cloudflare/raw/refs/heads/main/cf_push.sh"

# 定义下载脚本的函数
download_script() {
    local script_local=$1
    local script_api=$2
    local script_name=$3

    MAX_RETRIES=3
    RETRY_DELAY=5
    retry_count=0

    while [ $retry_count -lt $MAX_RETRIES ]; do
        echo "获取 $script_name..."
        if content=$(curl -sL "$script_api" | jq -r '.content' | base64 -d); then
            echo "$content" > "$script_local"
            echo "$script_name 已更新"
            chmod +x "$script_local"
            break
        else
            echo "下载 $script_name 失败"
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $MAX_RETRIES ]; then
                echo "将在 $RETRY_DELAY 秒后重试..."
                sleep $RETRY_DELAY
            else
                echo "重试次数已达上限，退出"
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
        echo "$script_name 执行完成"
    else
        echo "执行 $script_name 失败"
        exit 1
    fi
}

# 初始化包列表
packages=""

# 检查依赖是否安装
check_dependency() {
    local dependency=$1
    local package_name=$2

    if ! command -v "$dependency" &> /dev/null; then
        echo "$dependency 未找到，将其添加到所需软件包列表中"
        packages="$packages $package_name"
    else
        echo "$dependency 已安装"
    fi
}

# 检查所有依赖
check_dependency "jq" "jq"
check_dependency "yq" "yq"
check_dependency "tar" "tar"
check_dependency "sed" "sed"
check_dependency "awk" "gawk"
check_dependency "tr" "coreutils"

# 判断系统进行安装
if [ -n "$packages" ]; then
    echo "以下软件包是必需的: $packages"
    if grep -qi "alpine" /etc/os-release; then
        echo "使用 apk 安装软件包..."
        apk update
        apk add $packages
    elif grep -qi "openwrt" /etc/os-release; then
        echo "使用 opkg 安装软件包..."
        opkg update
        for package in $packages; do
            opkg install "$package"
        done
        # openwrt 没有安装 timeout
        opkg install coreutils-timeout
    elif grep -qi "ubuntu\|debian" /etc/os-release; then
        echo "使用 apt-get 安装软件包..."
        sudo apt-get update
        sudo apt-get install $packages
    elif grep -qi "centos\|red hat\|fedora" /etc/os-release; then
        echo "使用 yum 安装软件包..."
        sudo yum install $packages
    else
        echo "未能检测出你的系统：$(uname)，请自行安装 $packages 这些软件"
        exit 1
    fi
fi

# 下载所有脚本
download_script "$RESOLVE_SCRIPT_LOCAL" "$RESOLVE_SCRIPT_API" "cf"

download_script "$SETUP_SCRIPT_LOCAL" "$SETUP_SCRIPT_API" "setup_cloudflarest.sh"
download_script "$START_DDNS_LOCAL" "$START_DDNS_API" "start_ddns.sh"
download_script "$CF_PUSH_LOCAL" "$CF_PUSH_API" "cf_push.sh"

# 执行 setup_cloudflarest.sh
./setup_cloudflarest.sh
