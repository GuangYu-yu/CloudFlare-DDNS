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
    *) echo "不支持的架构: $ARCH"; exit 1 ;;
esac

# 获取最新版本号
LATEST_VERSION=$(curl -s https://api.github.com/repos/XIU2/CloudflareSpeedTest/releases/latest | grep 'tag_name' | cut -d '"' -f 4)
if [ -z "$LATEST_VERSION" ]; then
    echo "无法从 GitHub 获取最新版本信息"
    exit 1
fi

# 下载的压缩包文件名
FILENAME="CloudflareST_linux_${FILE_SUFFIX}.tar.gz"
DOWNLOAD_URL="https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
SIZE_THRESHOLD=2500000  # 字节

# 尝试下载文件并检查其完整性
download_file() {
    local url=$1
    local file=$2
    local max_retries=3
    local attempt=0

    while [ $attempt -lt $max_retries ]; do
        echo "从 $url 下载"
        curl -L --silent --output "$file" "$url"

        # 检查 HTTP 状态码
        if [ $? -eq 0 ]; then
            local file_size=$(stat -c %s "$file")
            echo "下载完成，文件大小：$file_size 字节"

            if [ "$file_size" -ge "$SIZE_THRESHOLD" ]; then
                return 0
            else
                echo "文件太小：$file_size 字节"
            fi
        else
            echo "下载失败"
        fi

        attempt=$((attempt + 1))
        echo "重试 $attempt/$max_retries..."
    done

    return 1
}

# 下载主地址
if download_file "$DOWNLOAD_URL" "$FILENAME"; then
    echo "下载完成。"
else
    # 尝试其他下载源
    DOWNLOAD_SOURCES=(
        "https://download.scholar.rr.nu/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
        "https://ghproxy.cc/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
        "https://ghproxy.net/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
        "https://gh-proxy.com/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
        "https://mirror.ghproxy.com/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
    )

    for SOURCE in "${DOWNLOAD_SOURCES[@]}"; do
        if download_file "$SOURCE" "$FILENAME"; then
            echo "下载完成。"
            break
        else
            echo "尝试从 $SOURCE 下载失败。"
        fi
    done
fi

# 检查文件是否下载成功
if [ ! -f "$FILENAME" ]; then
    echo "下载失败，请检查网络连接或手动下载文件。"
    exit 1
fi

# 解压文件
echo "解压文件..."
if tar -zxf "$FILENAME"; then
    echo "文件解压完成。"
else
    echo "解压文件失败。"
    exit 1
fi

# 赋予执行权限
chmod +x CloudflareST

echo "设置完成！"
