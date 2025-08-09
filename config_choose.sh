#!/bin/bash

# OpenClash 配置文件切换脚本
# 支持简写、完整文件名、绝对路径、相对路径

CONFIG_DIR="/etc/openclash/config"

# 获取实际配置文件路径
get_config_path() {
    local input="$1"
    
    # 如果是绝对路径
    if [[ "$input" == /* ]]; then
        echo "$input"
        return
    fi
    
    # 如果是相对路径
    if [[ "$input" == ./* ]] || [[ "$input" == ../* ]]; then
        echo "$(realpath "$input")"
        return
    fi
    
    # 如果是完整文件名
    if [[ "$input" == *.yaml ]] || [[ "$input" == *.yml ]]; then
        echo "$CONFIG_DIR/$input"
        return
    fi
    
    # 如果是简写，自动补全扩展名
    if [[ -f "$CONFIG_DIR/$input.yaml" ]]; then
        echo "$CONFIG_DIR/$input.yaml"
    elif [[ -f "$CONFIG_DIR/$input.yml" ]]; then
        echo "$CONFIG_DIR/$input.yml"
    else
        echo "错误: 配置文件不存在: $input" >&2
        exit 1
    fi
}

# 检查参数
if [[ $# -ne 1 ]]; then
    echo "用法: $0 <配置文件>" >&2
    echo "示例:" >&2
    echo "  $0 config1" >&2
    echo "  $0 config1.yaml" >&2
    echo "  $0 /etc/openclash/config/config1.yaml" >&2
    exit 1
fi

CONFIG_PATH=$(get_config_path "$1")

# 验证配置文件
if [[ ! -f "$CONFIG_PATH" ]]; then
    echo "错误: 配置文件不存在: $CONFIG_PATH" >&2
    exit 1
fi

# 切换配置
echo "切换到: $(basename "$CONFIG_PATH")"
/etc/init.d/openclash stop
uci set openclash.config.config_path="$CONFIG_PATH"
uci commit openclash
/etc/init.d/openclash start
echo "完成"