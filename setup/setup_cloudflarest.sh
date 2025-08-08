#!/bin/bash

# 获取当前系统架构
ARCH=$(uname -m)

# 根据系统架构选择相应的文件名
case "$ARCH" in
    x86_64) 
        FILENAME="CloudflareST-Rust_linux_amd64.tar.gz"
        DOWNLOAD_URL="https://github.com/GuangYu-yu/CloudflareST-Rust/releases/download/latest/CloudflareST-Rust_linux_amd64.tar.gz"
        ;;
    aarch64) 
        FILENAME="CloudflareST-Rust_linux_arm64.tar.gz"
        DOWNLOAD_URL="https://github.com/GuangYu-yu/CloudflareST-Rust/releases/download/latest/CloudflareST-Rust_linux_arm64.tar.gz"
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
    if curl --max-time 10 -O "$DOWNLOAD_URL"; then
        echo "下载成功！"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "下载失败，重试第 $RETRY_COUNT 次..."
    fi
done

# 清理临时文件
rm -rf "$TEMP_DIR"

# 解压
tar -zxf "$FILENAME" && rm -f "$FILENAME"

# 删除压缩包
rm -f "$FILENAME"

# 赋予执行权限
chmod +x CloudflareST-Rust

echo "CloudflareST-Rust 获取完成！"
