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

# 定义镜像源列表
MIRRORS=(
    "$DOWNLOAD_URL"
    "https://download.scholar.rr.nu/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
    "https://ghproxy.cc/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
    "https://ghproxy.net/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
    "https://gh-proxy.com/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
    "https://mirror.ghproxy.com/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
)

# 使用 tcping 测试各个镜像的延迟，选择最快的源
BEST_MIRROR=""
BEST_TIME=1000000
for MIRROR in "${MIRRORS[@]}"; do
    HOST=$(echo "$MIRROR" | awk -F/ '{print $3}')
    echo "正在测试 $HOST 的响应时间..."
    TIME=$(tcping -c 3 "$HOST" | grep 'min/avg/max' | awk -F'/' '{print $5}' | sed 's/[^0-9.]//g')
    
    if [ -z "$TIME" ]; then
        echo "$HOST 测试失败，跳过。"
        continue
    fi

    echo "$HOST 平均延迟: $TIME ms"
    if (( $(echo "$TIME < $BEST_TIME" | bc -l) )); then
        BEST_TIME="$TIME"
        BEST_MIRROR="$MIRROR"
    fi
done

# 如果没有找到可用的镜像，退出
if [ -z "$BEST_MIRROR" ]; then
    echo "没有可用的下载源。"
    exit 1
fi

echo "选择最快的下载源: $BEST_MIRROR"
wget -N "$BEST_MIRROR" || {
    echo "下载失败，请重试。"
    exit 1
}

# 解压文件
tar -zxf "$FILENAME"

# 赋予执行权限
chmod +x CloudflareST

echo "设置完成！"
