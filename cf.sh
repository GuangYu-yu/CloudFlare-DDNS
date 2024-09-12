#!/bin/bash

# 配置文件路径
config_file="config.cfg"

# 检查并创建配置文件
if [ ! -f "$config_file" ]; then
    touch "$config_file"
fi

# 显示网络支持状态
detect_ip_addresses() {
    ipv6_support=$(curl -s6 ifconfig.co || curl -s6 ipinfo.io || curl -s6 test.ipw.cn || curl -s6 api64.ipify.org > /dev/null && echo "IPv6: √" || echo "IPv6: ×")
    ipv4_support=$(curl -s4 ifconfig.co || curl -s4 ipinfo.io || curl -s4 test.ipw.cn || curl -s4 api64.ipify.org > /dev/null && echo "IPv4: √" || echo "IPv4: ×")
    echo "$ipv6_support"
    echo "$ipv4_support"
}

# 读取账户配置
load_account_info() {
    if [ -f "$config_file" ]; then
        source "$config_file"
    else
        echo "未找到配置文件，无法加载账户信息。"
    fi
}

# 保存账户信息到配置文件
save_account_info() {
    echo "email=$email" > "$config_file"
    echo "zone_id=$zone_id" >> "$config_file"
    echo "api_key=$api_key" >> "$config_file"
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo "================================="
        echo "           主菜单"
        echo "================================="
        detect_ip_addresses
        echo "1. 设置账户"
        echo "2. 解析地址"
        echo "3. 推送设置"
        echo "4. 执行解析"
        echo "5. 退出"
        read -p "请选择功能（留空则返回上级）: " choice

        case $choice in
            1) account_settings ;;
            2) resolve_settings ;;
            3) push_settings ;;
            4) execute_resolve ;;
            5) exit 0 ;;
            *) echo "无效选项，请重新选择。" ;;
        esac
    done
}

# 账户设置菜单
account_settings() {
    while true; do
        clear
        echo "================================="
        echo "         账户设置"
        echo "================================="
        echo "1. 添加账户"
        echo "2. 删除账户"
        echo "3. 修改账户"
        read -p "请选择功能（留空则返回上级）: " account_choice

        case $account_choice in
            1) add_account ;;
            2) delete_account ;;
            3) modify_account ;;
            *) break ;;
        esac
    done
}

# 添加账户
add_account() {
    echo "请设置账户信息："
    read -p "输入登录邮箱: " email
    read -p "输入区域ID: " zone_id
    read -p "输入API Key: " api_key

    # 保存账户信息
    save_account_info

    echo "账户添加成功"
    read -p "按任意键返回..."
}

# 删除账户
delete_account() {
    > "$config_file"  # 清空配置文件
    echo "账户删除成功"
    read -p "按任意键返回..."
}

# 修改账户
modify_account() {
    echo "当前账户信息："
    load_account_info
    echo "邮箱: $email"
    echo "区域ID: $zone_id"
    echo "API Key: $api_key"

    echo "请重新设置账户信息："
    read -p "输入登录邮箱: " email
    read -p "输入区域ID: " zone_id
    read -p "输入API Key: " api_key

    # 保存账户信息
    save_account_info

    echo "账户修改成功"
    read -p "按任意键返回..."
}

# 解析设置菜单
resolve_settings() {
    while true; do
        clear
        echo "================================="
        echo "         解析设置"
        echo "================================="
        echo "1. 添加解析"
        echo "2. 删除解析"
        echo "3. 修改解析"
        echo "4. 查看计划任务"
        read -p "请选择功能（留空则返回上级）: " resolve_choice

        case $resolve_choice in
            1) add_resolve ;;
            2) delete_resolve ;;
            3) modify_resolve ;;
            4) view_scheduled_tasks ;;
            *) break ;;
        esac
    done
}

# 添加解析
add_resolve() {
    load_account_info
    if [ -z "$email" ] || [ -z "$zone_id" ] || [ -z "$api_key" ]; then
        echo "请先设置账户信息。"
        read -p "按任意键返回..."
        return
    fi

    echo "请选择解析模式："
    echo "1. 多个IP分别解析到多个域名"
    echo "2. 多个IP解析到同一个域名"
    read -p "选择模式: " resolve_mode

    if [[ $resolve_mode == 1 ]]; then
        read -p "请输入多个二级域名（以空格分开）: " subdomains
    elif [[ $resolve_mode == 2 ]]; then
        read -p "请输入一个二级域名: " subdomain
    else
        echo "无效的选择。"
        return
    fi

    # 输入IP数量
    read -p "请输入IPv4和IPv6地址解析数量（空格分开）: " ipv4_count ipv6_count

    # 输入 CloudflareST 测速命令
    read -p "请输入CloudflareST命令（以./CloudflareST开头）: " cfst_command

    # 保存解析信息
    echo "解析设置成功"
    read -p "按任意键返回..."
}

# 查看计划任务
view_scheduled_tasks() {
    echo "查看计划任务功能尚未实现"
    read -p "按任意键返回..."
}

# 推送设置菜单
push_settings() {
    while true; do
        clear
        echo "================================="
        echo "         推送设置"
        echo "================================="
        echo "1. 设置Telegram推送"
        echo "2. 设置PushPlus推送"
        read -p "请选择功能（留空则返回上级）: " push_choice

        case $push_choice in
            1) set_telegram ;;
            2) set_pushplus ;;
            *) break ;;
        esac
    done
}

# 设置Telegram推送
set_telegram() {
    read -p "请输入Telegram Bot Token: " telegramBotToken
    read -p "请输入Telegram用户ID: " telegramBotUserId
    echo "Telegram推送设置完成"
    read -p "按任意键返回..."
}

# 设置PushPlus推送
set_pushplus() {
    read -p "请输入PushPlus Token: " PushPlusToken
    echo "PushPlus推送设置完成"
    read -p "按任意键返回..."
}

# 执行解析
execute_resolve() {
    load_account_info
    if [ -z "$email" ] || [ -z "$zone_id" ] || [ -z "$api_key" ]; then
        echo "请先设置账户信息。"
        read -p "按任意键返回..."
        return
    fi

    echo "执行CloudflareST解析并测速..."
    # 执行 CloudflareST 命令
    # 示例: ./CloudflareST -n 200 -t 4 ...
    result=$($cfst_command)

    # 输出解析结果并推送到TG或PushPlus
    message_text=$(echo "$result" | sed "$ ! s/$/\\%0A/ ")

    # 推送到Telegram
    if [[ ! -z $telegramBotToken && ! -z $telegramBotUserId ]]; then
        TGURL="https://api.telegram.org/bot${telegramBotToken}/sendMessage"
        res=$(curl -s -X POST $TGURL -H "Content-type:application/json" -d "{\"chat_id\":\"$telegramBotUserId\", \"parse_mode\":\"HTML\", \"text\":\"$message_text\"}")
        echo "Telegram推送完成"
    fi

    # 推送到PushPlus
    if [[ ! -z $PushPlusToken ]]; then
        PushPlusURL="http://www.pushplus.plus/send"
        res=$(curl -s -X POST $PushPlusURL -d "token=${PushPlusToken}" -d "title=解析结果推送" -d "content=${message_text}" -d "template=html")
        echo "PushPlus推送完成"
    fi

    echo "解析完成"
    read -p "按任意键返回..."
}

# 启动主菜单
main_menu
