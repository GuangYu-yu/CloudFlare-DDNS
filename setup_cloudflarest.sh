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

# 下载 URL
DOWNLOAD_URL="https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"

# 下载超时设置（秒）
TIMEOUT=30
# 文件大小阈值（字节）
SIZE_THRESHOLD=2500000

# 尝试下载文件
download_file() {
    local url=$1
    local file=$2

    echo "从 $url 下载"
    curl --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" -L "$url" -o "$file" --silent --show-error --write-out "%{size_download}" | {
        read downloaded_size
        if [ "$downloaded_size" -ge "$SIZE_THRESHOLD" ]; then
            echo "下载完成，文件大小：$downloaded_size 字节"
            return 0
        else
            echo "下载失败或文件太小，尝试使用其他镜像..."
            return 1
        fi
    }
}

# 尝试从主下载源下载
if download_file "$DOWNLOAD_URL" "$FILENAME"; then
    echo "下载完成。"
else
    # 尝试使用镜像下载
    MIRRORS=(
        "https://download.scholar.rr.nu/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
        "https://ghproxy.cc/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
        "https://ghproxy.net/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
        "https://gh-proxy.com/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
        "https://mirror.ghproxy.com/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
    )
    for MIRROR in "${MIRRORS[@]}"; do
        if download_file "$MIRROR" "$FILENAME"; then
            echo "下载完成。"
            break
        fi
    done
fi

# 解压文件
tar -zxf "$FILENAME"

# 赋予执行权限
chmod +x CloudflareST

echo "设置完成！"
