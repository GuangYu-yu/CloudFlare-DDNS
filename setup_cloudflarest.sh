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

# 获取最新版本信息
RELEASE_API="https://api.github.com/repos/XIU2/CloudflareSpeedTest/releases/latest"
release_info=$(curl -s "$RELEASE_API")
LATEST_VERSION=$(echo "$release_info" | jq -r '.tag_name')

if [ -z "$LATEST_VERSION" ]; then
    echo "无法从 GitHub API 获取版本信息"
    exit 1
fi

# 设置下载文件名
FILENAME="CloudflareST_linux_${FILE_SUFFIX}.tar.gz"

# 获取资源ID
asset_id=$(echo "$release_info" | jq -r ".assets[] | select(.name == \"$FILENAME\") | .id")

if [ -z "$asset_id" ]; then
    echo "无法获取资源ID"
    exit 1
fi

# 如果文件存在，则删除
if [ -f "$FILENAME" ]; then
    echo "$FILENAME 已存在，删除旧文件..."
    rm -f "$FILENAME"
fi

# 下载文件
echo "正在下载 $FILENAME..."
MAX_RETRIES=3
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -L -H "Accept: application/octet-stream" \
        "https://api.github.com/repos/XIU2/CloudflareSpeedTest/releases/assets/$asset_id" \
        --output "$FILENAME"; then
        echo "下载成功！"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            echo "下载失败，第 $RETRY_COUNT 次重试..."
            sleep 5
        else
            echo "下载失败，已达到最大重试次数"
            exit 1
        fi
    fi
done

# 只解压出名为 CloudflareST 的文件
tar -zxf "$FILENAME" --wildcards 'CloudflareST'

# 删除压缩包
rm -f "$FILENAME"

# 赋予执行权限
chmod +x CloudflareST

echo "设置完成！"