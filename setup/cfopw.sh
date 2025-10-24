#!/bin/bash

# 定义要下载的项目名称，可以添加更多项目
PROJECT_NAMES=("CloudflareST-Rust" "CloudFlare-DDNS")

# 定义每个项目的配置信息
# 格式: "项目名:用户名:分支名:AMD文件名:ARM文件名"
FILE_MAPPINGS=(
    "CloudflareST-Rust:GuangYu-yu:main-latest:CloudflareST_linux_amd64.tar.gz:CloudflareST_linux_arm64.tar.gz"
    "CloudFlare-DDNS:GuangYu-yu:main-latest:CFRS_linux_amd64.tar.gz:CFRS_linux_arm64.tar.gz"
)

# 获取当前系统架构
ARCH=$(uname -m)

# 下载函数
download_project() {
    local PROJECT_NAME="$1"
    local USERNAME=""
    local BRANCH_NAME=""
    local AMD_FILENAME=""
    local ARM_FILENAME=""
    
    # 查找项目对应的配置信息
    for mapping in "${FILE_MAPPINGS[@]}"; do
        IFS=':' read -r -a parts <<< "$mapping"
        if [ "${parts[0]}" = "$PROJECT_NAME" ]; then
            USERNAME="${parts[1]}"
            BRANCH_NAME="${parts[2]}"
            AMD_FILENAME="${parts[3]}"
            ARM_FILENAME="${parts[4]}"
            break
        fi
    done
    
    # 根据系统架构选择相应的文件名
    case "$ARCH" in
        x86_64) 
            FILENAME="$AMD_FILENAME"
            DOWNLOAD_URL="https://github.com/${USERNAME}/${PROJECT_NAME}/releases/download/${BRANCH_NAME}/$AMD_FILENAME"
            ;;
        aarch64) 
            FILENAME="$ARM_FILENAME"
            DOWNLOAD_URL="https://github.com/${USERNAME}/${PROJECT_NAME}/releases/download/${BRANCH_NAME}/$ARM_FILENAME"
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
}

# 循环下载所有项目
for project in "${PROJECT_NAMES[@]}"; do
    download_project "$project"
done
