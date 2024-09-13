#!/bin/bash

# 创建 CloudflareST 文件夹
mkdir -p CloudflareST

# 进入文件夹
cd CloudflareST

# 获取当前系统架构
ARCH=$(uname -m)

# 根据系统架构选择相应的文件名
case "$ARCH" in
    x86_64) FILE_SUFFIX="amd64" ;;
    i386|i686) FILE_SUFFIX="386" ;;
    aarch64) FILE_SUFFIX="arm64" ;;
    armv5*) FILE_SUFFIX="armv5" ;;
    armv6*) FILE_SUFFIX="armv6" ;;
    armv7*) FILE_SUFFIX="armv7" ;;
    mips) FILE_SUFFIX="mips" ;;
    mips64) FILE_SUFFIX="mips64" ;;
    mipsle) FILE_SUFFIX="mipsle" ;;
    mips64le) FILE_SUFFIX="mips64le" ;;
    *)
        echo "不支持的架构: $ARCH"
        exit 1 ;;
esac

# 获取最新版本号
LATEST_VERSION=$(curl -s https://api.github.com/repos/XIU2/CloudflareSpeedTest/releases/latest | grep 'tag_name' | cut -d '"' -f 4)
if [ -z "$LATEST_VERSION" ]; then
    echo "无法从 GitHub 获取最新版本信息"
    exit 1
fi

# 下载的压缩包文件名
FILENAME="CloudflareST_linux_${FILE_SUFFIX}.tar.gz"

# 如果文件存在，则删除
if [ -f "$FILENAME" ]; then
    echo "$FILENAME 已存在，删除旧文件..."
    rm -f "$FILENAME"
fi

# 定义下载源列表
SOURCES=(
    "https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
    "https://download.scholar.rr.nu/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
    "https://ghproxy.cc/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
    "https://ghproxy.net/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
    "https://gh-proxy.com/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
    "https://mirror.ghproxy.com/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
)

# 遍历下载源列表，使用curl测试连通性
for SOURCE in "${SOURCES[@]}"; do
    if curl --connect-timeout 5 --output /dev/null --silent --head --fail "$SOURCE"; then
        DOWNLOAD_URL="$SOURCE"
        echo "首个可用的下载源: $DOWNLOAD_URL"
        break
    fi
done

# 如果找到可用的下载源，则进行下载
if [ -n "$DOWNLOAD_URL" ]; then
    echo "从 $DOWNLOAD_URL 下载"
    wget -N "$DOWNLOAD_URL" || {
        RETRY_COUNT=0
        MAX_RETRIES=3
        while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
            RETRY_COUNT=$((RETRY_COUNT + 1))
            echo "下载失败，重试第 $RETRY_COUNT 次..."
            wget -N "$DOWNLOAD_URL" && break
        done
        if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
            echo "所有重试均失败，下载终止。"
            exit 1
        fi
    }
else
    echo "所有下载源均不可用，下载失败。"
    exit 1
fi

# 解压文件
tar -zxf "$FILENAME"

# 删除压缩包
rm -f "$FILENAME"

# 赋予执行权限
chmod +x CloudflareST

echo "设置完成！"
