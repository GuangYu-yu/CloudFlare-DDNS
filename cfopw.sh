#!/bin/bash

# 定义文件路径和API URL

RESOLVE_SCRIPT_LOCAL="cf"
RESOLVE_SCRIPT_API="https://gitee.com/zhxdcyy/sh/raw/master/cf"

START_DDNS_LOCAL="start_ddns.sh"
START_DDNS_API="https://gitee.com/zhxdcyy/sh/raw/master/start_ddns.sh"

CF_PUSH_LOCAL="cf_push.sh"
CF_PUSH_API="https://gitee.com/zhxdcyy/sh/raw/master/cf_push.sh"

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
        if curl -sL "$script_api" -o "$script_local"; then
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

# 检查依赖函数
check_dependency() {
    local dependency=$1
    local package_name=$2
    if ! command -v "$dependency" >/dev/null 2>&1; then
        echo "$dependency 未找到，将其添加到待安装软件包列表中"
        packages="$packages $package_name"
    else
        echo "$dependency 已安装"
    fi
}

# 检查依赖
check_dependency "jq" "jq"
check_dependency "yq" "yq"
check_dependency "tar" "tar"
check_dependency "sed" "sed"
check_dependency "awk" "gawk"
check_dependency "tr" "coreutils"

# 先单独安装 timeout (针对 OpenWrt)
if ! command -v timeout >/dev/null 2>&1; then
    if command -v opkg >/dev/null 2>&1; then
        echo "检测到缺少 timeout 命令，尝试使用 opkg 安装 coreutils-timeout"
        opkg update
        opkg install coreutils-timeout
    else
        echo "警告：缺少 timeout 命令，请确保 coreutils 已安装"
    fi
fi

# 自动检测包管理器进行安装
if [ -n "$packages" ]; then
    echo "需要安装以下软件包: $packages"

    if command -v pkg >/dev/null 2>&1; then
        echo "检测到 pkg，使用 pkg 安装"
        pkg update
        pkg install $packages
    elif command -v apt-get >/dev/null 2>&1; then
        echo "检测到 apt-get，使用 apt-get 安装"
        sudo apt-get update
        sudo apt-get install -y $packages
    elif command -v apk >/dev/null 2>&1; then
        echo "检测到 apk，使用 apk 安装"
        apk update
        apk add $packages
    elif command -v yum >/dev/null 2>&1; then
        echo "检测到 yum，使用 yum 安装"
        sudo yum install -y $packages
    elif command -v dnf >/dev/null 2>&1; then
        echo "检测到 dnf，使用 dnf 安装"
        sudo dnf install -y $packages
    elif command -v pacman >/dev/null 2>&1; then
        echo "检测到 pacman，使用 pacman 安装"
        sudo pacman -Sy --noconfirm $packages
    elif command -v zypper >/dev/null 2>&1; then
        echo "检测到 zypper，使用 zypper 安装"
        sudo zypper install -y $packages
    elif command -v opkg >/dev/null 2>&1; then
        echo "检测到 opkg，使用 opkg 安装"
        opkg update
        opkg install $packages
    else
        echo "未检测到已知的包管理器，请手动安装: $packages"
        exit 1
    fi
fi

# 下载所有脚本
download_script "$RESOLVE_SCRIPT_LOCAL" "$RESOLVE_SCRIPT_API" "cf"
download_script "$START_DDNS_LOCAL" "$START_DDNS_API" "start_ddns.sh"
download_script "$CF_PUSH_LOCAL" "$CF_PUSH_API" "cf_push.sh"

# 执行 setup_cloudflarest.sh
curl -ksSL https://gitee.com/zhxdcyy/sh/raw/master/setup_cloudflarest.sh | bash
