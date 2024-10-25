#!/bin/bash

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
    "https://ghp.ci/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
    "https://download.scholar.rr.nu/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
    "https://ghproxy.cc/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
    "https://ghproxy.net/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
    "https://gh-proxy.com/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
)

# 官方下载源
OFFICIAL_SOURCE="https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"

# 定义重试次数
MAX_RETRIES=3

# 遍历下载源列表，尝试下载
for SOURCE in "${SOURCES[@]}"; do
    echo "尝试从 $SOURCE 下载..."
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if wget --timeout=10 -N "$SOURCE"; then
            echo "下载成功！"
            break 2
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            echo "下载失败，重试第 $RETRY_COUNT 次..."
        fi
    done
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "从 $SOURCE 下载失败，尝试下一个下载源..."
    fi
done

# 如果所有其他下载源均失败，则使用官方下载源
if [ ! -f "$FILENAME" ]; then
    echo "所有其他下载源均不可用，尝试官方下载源: $OFFICIAL_SOURCE"
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt 2 ]; do
        echo "从 $OFFICIAL_SOURCE 下载..."
        if wget --timeout=30 -N "$OFFICIAL_SOURCE"; then
            echo "下载成功！"
            break
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            echo "下载失败，重试第 $RETRY_COUNT 次..."
        fi
    done
    if [ $RETRY_COUNT -eq 2 ]; then
        echo "从官方下载源下载失败，下载终止。"
        exit 1
    fi
fi

# 只解压出名为 CloudflareST 的文件
tar -zxf "$FILENAME" --wildcards 'CloudflareST'

# 删除压缩包
rm -f "$FILENAME"

# 赋予执行权限
chmod +x CloudflareST

echo "设置完成！"

rm setup_cloudflarest.sh
