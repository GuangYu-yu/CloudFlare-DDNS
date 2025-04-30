#!/bin/bash

# 获取当前系统架构
ARCH=$(uname -m)

# 根据系统架构选择相应的文件名
case "$ARCH" in
    x86_64) 
        FILENAME="CloudflareST-Rust_linux_amd64.tar.gz"
        ;;
    aarch64) 
        FILENAME="CloudflareST-Rust_linux_arm64.tar.gz"
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

# 创建临时文件存储延迟测试结果
TEMP_DIR=$(mktemp -d)
RESULTS_FILE="$TEMP_DIR/results"

# 测试单个域名的延迟的函数
test_domain_latency() {
    local DOMAIN=$1
    local URL=$2
    local OUTPUT_FILE=$3
    
    TOTAL=0
    SUCCESS=0
    for i in {1..3}; do
        LATENCY=$(curl --max-time 5 -o /dev/null -s -w "%{time_total}\n" "$URL" 2>/dev/null)
        if [ $? -eq 0 ]; then
            TOTAL=$(awk "BEGIN {print $TOTAL + $LATENCY}")
            SUCCESS=$((SUCCESS + 1))
        fi
    done
    
    if [ $SUCCESS -gt 0 ]; then
        AVG=$(awk "BEGIN {printf \"%.3f\", $TOTAL / $SUCCESS}")
        echo "$AVG $DOMAIN" >> "$OUTPUT_FILE"
        echo "$DOMAIN 平均延迟: ${AVG}s"
    else
        echo "999999 $DOMAIN" >> "$OUTPUT_FILE"
        echo "$DOMAIN 无法连接"
    fi
}

# 定义下载源列表
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

# 并发测试所有域名的延迟
echo "并发测试下载源延迟中..."
for DOMAIN in "${!DOMAINS[@]}"; do
    test_domain_latency "$DOMAIN" "${DOMAINS[$DOMAIN]}" "$RESULTS_FILE" &
done

# 等待所有测试完成
wait

# 读取并排序结果
SORTED_DOMAINS=($(sort -n "$RESULTS_FILE" | cut -d' ' -f2))

# 构建下载URL列表
declare -a SOURCES
for DOMAIN in "${SORTED_DOMAINS[@]}"; do
    if [ "$DOMAIN" = "github.com" ]; then
        SOURCES+=("https://github.com/GuangYu-yu/CloudflareST-Rust/releases/latest/download/$FILENAME")
    else
        SOURCES+=("${DOMAINS[$DOMAIN]}/https://github.com/GuangYu-yu/CloudflareST-Rust/releases/latest/download/$FILENAME")
    fi
done

# 定义重试次数
MAX_RETRIES=3

# 尝试从排序后的源下载
for URL in "${SOURCES[@]}"; do
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

# 清理临时文件
rm -rf "$TEMP_DIR"

# 如果所有下载源均失败，退出
if [ ! -f "$FILENAME" ]; then
    echo "所有下载源均不可用，下载终止。"
    exit 1
fi

# 只解压出名为 CloudflareST 的文件
tar -zxf "$FILENAME" --wildcards 'CloudflareST-Rust'

# 删除压缩包
rm -f "$FILENAME"

# 赋予执行权限
chmod +x CloudflareST-Rust

echo "设置完成！"

echo "使用bash cf进入主菜单"

rm setup_cloudflarest.sh