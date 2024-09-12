#!/bin/bash

# 创建 CloudflareST 文件夹
mkdir -p CloudflareST

# 进入文件夹
cd CloudflareST

# 获取当前系统架构
ARCH=$(uname -m)
# 根据系统架构选择相应的文件名
case "$ARCH" in
    x86_64)
        FILE_SUFFIX="amd64"
        ;;
    i386|i686)
        FILE_SUFFIX="386"
        ;;
    aarch64)
        FILE_SUFFIX="arm64"
        ;;
    armv5*)
        FILE_SUFFIX="armv5"
        ;;
    armv6*)
        FILE_SUFFIX="armv6"
        ;;
    armv7*)
        FILE_SUFFIX="armv7"
        ;;
    mips)
        FILE_SUFFIX="mips"
        ;;
    mips64)
        FILE_SUFFIX="mips64"
        ;;
    mipsle)
        FILE_SUFFIX="mipsle"
        ;;
    mips64le)
        FILE_SUFFIX="mips64le"
        ;;
    *)
        echo "不支持的架构: $ARCH"
        exit 1
        ;;
esac

# 获取最新版本号
LATEST_VERSION=$(curl -s https://api.github.com/repos/XIU2/CloudflareSpeedTest/releases/latest | grep 'tag_name' | cut -d '"' -f 4)
if [ -z "$LATEST_VERSION" ]; then
    echo "无法从 GitHub 获取最新版本信息"
    exit 1
fi

# 下载的压缩包文件名
FILENAME="CloudflareST_linux_${FILE_SUFFIX}.tar.gz"

# 检查是否已有最新版本
if [ -f "$FILENAME" ]; then
    echo "$FILENAME 已经存在。检查是否是最新版本..."
    CURRENT_VERSION=$(tar -tf "$FILENAME" | grep -oP 'v\d+\.\d+\.\d+' | head -n 1)
    if [ "$CURRENT_VERSION" == "$LATEST_VERSION" ]; then
        echo "已经下载了最新版本 $LATEST_VERSION。"
        exit 0
    fi
    echo "现有版本 ($CURRENT_VERSION) 不是最新版本。正在下载最新版本..."
fi

# 下载最新版本的 CloudflareST
DOWNLOAD_URL="https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
echo "从 $DOWNLOAD_URL 下载"
wget -N "$DOWNLOAD_URL" || {
    echo "从 GitHub 下载失败。尝试使用镜像..."
    MIRRORS=(
        "https://download.scholar.rr.nu/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
        "https://ghproxy.cc/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
        "https://ghproxy.net/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
        "https://gh-proxy.com/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
        "https://mirror.ghproxy.com/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
    )
    for MIRROR in "${MIRRORS[@]}"; do
        echo "尝试使用镜像: $MIRROR"
        wget -N "$MIRROR" && break
    done
}

# 解压文件
tar -zxf "$FILENAME"

# 赋予执行权限
chmod +x CloudflareST

echo "设置完成！"
