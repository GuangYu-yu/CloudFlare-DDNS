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

# 定义下载源列表（仅域名部分）
declare -A DOMAINS=(
    ["quantil.jsdelivr.net"]="https://quantil.jsdelivr.net"
    ["fastly.jsdelivr.net"]="https://fastly.jsdelivr.net"
    ["raw.staticdn.net"]="https://raw.staticdn.net"
    ["gh-proxy.com"]="https://gh-proxy.com"
    ["raw.gitmirror.com"]="https://raw.gitmirror.com"
    ["ghproxy.cc"]="https://ghproxy.cc"
    ["ghproxy.com"]="https://ghproxy.com"
    ["ghproxy.net"]="https://ghproxy.net"
    ["gcore.jsdelivr.net"]="https://gcore.jsdelivr.net"
    ["ghp.ci"]="https://ghp.ci"
    ["github.com"]="https://github.com"
    ["testingcf.jsdelivr.net"]="https://testingcf.jsdelivr.net"
    ["raw.gitmirror.com"]="https://raw.gitmirror.com"
)

# 测试域名延迟并排序
echo "测试下载源延迟中..."
declare -A LATENCIES
for DOMAIN in "${!DOMAINS[@]}"; do
    # 使用 curl 测试延迟（3次尝试取平均值）
    TOTAL=0
    SUCCESS=0
    for i in {1..3}; do
        LATENCY=$(curl -o /dev/null -s -w "%{time_total}\n" "${DOMAINS[$DOMAIN]}" 2>/dev/null)
        if [ $? -eq 0 ]; then
            TOTAL=$(echo "$TOTAL + $LATENCY" | bc)
            SUCCESS=$((SUCCESS + 1))
        fi
    done
    
    if [ $SUCCESS -gt 0 ]; then
        AVG=$(echo "scale=3; $TOTAL / $SUCCESS" | bc)
        LATENCIES[$DOMAIN]=$AVG
        echo "$DOMAIN 平均延迟: ${AVG}s"
    else
        LATENCIES[$DOMAIN]=999999
        echo "$DOMAIN 无法连接"
    fi
done

# 构建完整的下载URL列表（按延迟排序）
declare -a SOURCES
for DOMAIN in "${!LATENCIES[@]}"; do
    if [ "$DOMAIN" = "github.com" ]; then
        SOURCES+=("${LATENCIES[$DOMAIN]} https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME")
    else
        SOURCES+=("${LATENCIES[$DOMAIN]} ${DOMAINS[$DOMAIN]}/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/$FILENAME")
    fi
done

# 排序下载源（按延迟）
IFS=$'\n' SORTED_SOURCES=($(sort -n <<<"${SOURCES[*]}"))
unset IFS

# 定义重试次数
MAX_RETRIES=3

# 遍历排序后的下载源列表，尝试下载
for SOURCE in "${SORTED_SOURCES[@]}"; do
    # 提取URL（移除延迟值）
    URL=$(echo "$SOURCE" | cut -d' ' -f2-)
    echo "尝试从延迟最低的源下载: $URL"
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if wget --timeout=10 -N "$URL"; then
            echo "下载成功！"
            break 2
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            echo "下载失败，重试第 $RETRY_COUNT 次..."
        fi
    done
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "从 $URL 下载失败，尝试下一个下载源..."
    fi
done

# 如果所有下载源均失败，退出
if [ ! -f "$FILENAME" ]; then
    echo "所有下载源均不可用，下载终止。"
    exit 1
fi

# 只解压出名为 CloudflareST 的文件
tar -zxf "$FILENAME" --wildcards 'CloudflareST'

# 删除压缩包
rm -f "$FILENAME"

# 赋予执行权限
chmod +x CloudflareST

echo "设置完成！"

rm setup_cloudflarest.sh
