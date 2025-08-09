#!/bin/bash

# 获取当前系统架构
ARCH=$(uname -m)

# 根据系统架构选择相应的文件名
case "$ARCH" in
    x86_64) 
        FILENAME="CFRS_linux_amd64.tar.gz"
        DOWNLOAD_URL="https://github.com/GuangYu-yu/CloudFlare-DDNS/releases/download/latest/CFRS_linux_amd64.tar.gz"
        ;;
    aarch64) 
        FILENAME="CFRS_linux_arm64.tar.gz"
        DOWNLOAD_URL="https://github.com/GuangYu-yu/CloudFlare-DDNS/releases/download/latest/CFRS_linux_arm64.tar.gz"
        ;;
    *)
        echo "不支持的架构: $ARCH"
        exit 1 ;;
esac

# 如果文件存在，则删除
if [ -f "$FILENAME" ]; then
    echo "$FILENAME 已存在，删除旧文件..."
    rm -f "$FILENAME"
fi

# 定义重试次数
MAX_RETRIES=3
RETRY_COUNT=0

# 下载
echo "下载 $FILENAME"
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -fL --max-time 10 -O "$DOWNLOAD_URL"; then
        echo "下载成功！"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "下载失败，重试第 $RETRY_COUNT 次..."
    fi
done

# 清理临时文件
rm -rf "$TEMP_DIR"

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
check_dependency "tar" "tar"

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
    elif grep -qi "ubuntu\|debian" /etc/os-release; then
        echo "使用 apt-get 安装软件包..."
        sudo apt-get update
        sudo apt-get install $packages
    elif grep -qi "centos\|red hat\|fedora" /etc/os-release; then
        echo "使用 yum 安装软件包..."
        sudo yum install $packages
    else
        echo "未能检测出你的系统：$(uname)，请自行安装 $packages"
        exit 1
    fi
fi

# 解压
tar -zxf "$FILENAME" && rm -f "$FILENAME"

# 删除压缩包
rm -f "$FILENAME"

# 赋予执行权限
chmod +x CFRS

echo "CFRS 获取完成！"

# 执行 setup_cloudflarest.sh
curl -ksSL https://raw.githubusercontent.com/GuangYu-yu/CloudFlare-DDNS/refs/heads/main/setup/setup_cloudflarest.sh | bash
