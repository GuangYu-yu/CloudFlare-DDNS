#!/bin/bash

# 检查参数数量
if [ "$#" -ne 3 ]; then
    echo "从 https://github.com/<用户名>/<仓库名>/releases/download/latest/<文件名> 获取 .tar.gz 内可执行程序"
    echo "用法: $0 <用户名> <仓库名> <文件名>"
    exit 1
fi

# 从命令行参数获取值
USERNAME="$1"
PROJECT_NAME="$2"
FILENAME="$3"

# 构建下载URL
DOWNLOAD_URL="https://github.com/${USERNAME}/${PROJECT_NAME}/releases/download/latest/${FILENAME}"

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
