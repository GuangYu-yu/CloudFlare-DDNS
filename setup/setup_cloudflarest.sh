#!/bin/bash

# 项目名称
PROJECT_NAME="CloudflareST-Rust"

# 获取当前系统架构
ARCH=$(uname -m)

# 根据系统架构选择相应的文件名
case "$ARCH" in
    x86_64) 
        FILENAME="${PROJECT_NAME}_linux_amd64.tar.gz"
        DOWNLOAD_URL="https://github.com/GuangYu-yu/${PROJECT_NAME}/releases/download/latest/${PROJECT_NAME}_linux_amd64.tar.gz"
        ;;
    aarch64) 
        FILENAME="${PROJECT_NAME}_linux_arm64.tar.gz"
        DOWNLOAD_URL="https://github.com/GuangYu-yu/${PROJECT_NAME}/releases/download/latest/${PROJECT_NAME}_linux_arm64.tar.gz"
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
    if curl -fL --max-time 10 -o "$FILENAME" "$DOWNLOAD_URL"; then
        if [ -s "$FILENAME" ]; then
            echo "下载成功！"
            break
        else
            echo "下载失败：文件为空"
        fi
    else
        echo "下载失败"
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep 2
done

# 清理临时文件
rm -rf "$TEMP_DIR"

# 如果下载仍然失败
if [ ! -s "$FILENAME" ]; then
    echo "多次重试后仍未成功下载文件: $DOWNLOAD_URL"
    exit 1
fi

# 解压并检查
if tar -zxf "$FILENAME"; then
    rm -f "$FILENAME"
else
    echo "解压失败"
    exit 1
fi

# 赋予执行权限
chmod +x $PROJECT_NAME

echo "$PROJECT_NAME 获取完成！"
