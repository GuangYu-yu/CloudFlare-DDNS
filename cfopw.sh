#!/bin/bash

# 定义 setup_cloudflarest.sh 文件的 URL
SETUP_SCRIPT_URL="https://raw.githubusercontent.com/GuangYu-yu/opw-cloudflare/main/setup_cloudflarest.sh"
SETUP_SCRIPT_LOCAL="setup_cloudflarest.sh"

# 定义 cfopw.sh 文件的 URL
CFOPW_SCRIPT_URL="https://raw.githubusercontent.com/GuangYu-yu/opw-cloudflare/main/cfopw.sh"
CFOPW_SCRIPT_LOCAL="cfopw.sh"

# 检查文件是否需要更新
check_for_update() {
    local url=$1
    local local_file=$2

    # 获取远程文件的哈希值
    remote_hash=$(curl -s "$url" | sha256sum | cut -d ' ' -f1)

    # 获取本地文件的哈希值，如果文件存在
    if [ -f "$local_file" ]; then
        local_hash=$(sha256sum "$local_file" | cut -d ' ' -f1)
    else
        local_hash=""
    fi

    # 如果本地文件不存在或者哈希值不同，表示需要更新
    if [ "$remote_hash" != "$local_hash" ]; then
        return 0  # 需要更新
    else
        return 1  # 无需更新
    fi
}

# 下载并更新 setup_cloudflarest.sh
update_setup_script() {
    echo "正在检查 setup_cloudflarest.sh 是否需要更新..."

    if check_for_update "$SETUP_SCRIPT_URL" "$SETUP_SCRIPT_LOCAL"; then
        echo "发现新版本，正在下载..."
        curl -ksSL "$SETUP_SCRIPT_URL" -o "$SETUP_SCRIPT_LOCAL"
        chmod +x "$SETUP_SCRIPT_LOCAL"
        echo "setup_cloudflarest.sh 已更新并赋予可执行权限。"
    else
        echo "setup_cloudflarest.sh 已是最新版本，无需更新。"
    fi
}

# 下载并更新 cfopw.sh 自身
update_self() {
    echo "正在检查 cfopw.sh 是否需要更新..."

    if check_for_update "$CFOPW_SCRIPT_URL" "$CFOPW_SCRIPT_LOCAL"; then
        echo "发现新版本，正在下载..."
        curl -ksSL "$CFOPW_SCRIPT_URL" -o "$CFOPW_SCRIPT_LOCAL"
        chmod +x "$CFOPW_SCRIPT_LOCAL"
        echo "cfopw.sh 已更新并赋予可执行权限。"
    else
        echo "cfopw.sh 已是最新版本，无需更新。"
    fi
}

# 执行更新检查
update_setup_script
update_self

# 运行 setup_cloudflarest.sh 脚本
echo "正在执行 setup_cloudflarest.sh..."
./setup_cloudflarest.sh
