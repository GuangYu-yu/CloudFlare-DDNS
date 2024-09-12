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

# 检查是否已有文件存在，存在则删除
if [ -f "$FILENAME" ]; then
    echo "$FILENAME 已存在，正在删除旧文件..."
    rm -f "$FILENAME"
fi

# 下载源列表
MIRRORS=(
    "https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
    "https://download.scholar.rr.nu/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
    "https://ghproxy.cc/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
    "https://ghproxy.net/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
    "https://gh-proxy.com/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
    "https://mirror.ghproxy.com/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME"
)

# 通过并发 tcping 检测所有下载源，选择第一个成功的源进行下载
echo "正在测试下载源延迟..."
for MIRROR in "${MIRRORS[@]}"; do
    # 提取域名并使用 tcping 测试每个源的响应时间，设置超时时间为 5 秒
    DOMAIN=$(echo "$MIRROR" | sed 's|https://||' | cut -d '/' -f 1)
    echo "测试: $DOMAIN"
    if tcping -t 5 -c 3 "$DOMAIN" 443 &>/dev/null; then
        echo "选定下载源: $MIRROR"
        DOWNLOAD_URL="$MIRROR"
        break
    else
        echo "$DOMAIN 无法访问，继续测试其他源..."
    fi
done

if [ -z "$DOWNLOAD_URL" ]; then
    echo "所有下载源都无法访问，退出程序。"
    exit 1
fi

# 下载函数，监控下载速度
download_with_speed_check() {
    wget --limit-rate=500k -O "$FILENAME" "$DOWNLOAD_URL" 2>&1 | while IFS= read -r line; do
        echo "$line"
        # 获取当前下载速度，检测是否低于 100KB/s 且持续 10 秒
        speed=$(echo "$line" | grep -oE '[0-9]+[KM]B/s' | head -n 1)
        if [[ "$speed" =~ ^[0-9]+KB/s ]] && [ ${speed%KB/s} -lt 100 ]; then
            echo "下载速度低于 100KB/s，重试中..."
            killall wget
            return 1
        fi
    done
}

# 进行下载并监控
until download_with_speed_check; do
    echo "重新尝试下载..."
    sleep 2
done

# 解压文件
tar -zxf "$FILENAME"

# 赋予执行权限
chmod +x CloudflareST

echo "设置完成！"
