#!/bin/bash

# 检测设备是否有外网IPv4和IPv6地址，多个渠道检测，任意成功即表示支持
check_network_support() {
    IPV4=""
    IPV6=""

    # 多个渠道检测 IPv4 和 IPv6
    IPV4=$(curl -s4 ifconfig.co || curl -s4 ipinfo.io || curl -s4 api64.ipify.org)
    IPV6=$(curl -s6 ifconfig.co || curl -s6 ipinfo.io || curl -s6 api64.ipify.org)

    echo "检测网络支持状态："
    if [ -n "$IPV4" ]; then
        echo "支持 IPv4: $IPV4"
    else
        echo "不支持 IPv4"
    fi
    
    if [ -n "$IPV6" ]; then
        echo "支持 IPv6: $IPV6"
    else
        echo "不支持 IPv6"
    fi
}

# 存储解析规则的数组
declare -A resolve_rules

# 主菜单
main_menu() {
    while true; do
        echo "请选择功能："
        echo "1. 设置账户"
        echo "2. 解析地址"
        echo "3. 推送设置"
        echo "4. 执行解析"
        echo "5. 退出"
        read -p "请选择 (1-5): " choice

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
        echo "账户设置："
        echo "1. 添加账户"
        echo "2. 删除账户"
        echo "3. 修改账户"
        read -p "请选择功能（留空则返回上级）: " choice

        case $choice in
            1) add_account ;;
            2) remove_account ;;
            3) modify_account ;;
            "") return ;;
            *) echo "无效选项，请重新选择。" ;;
        esac
    done
}

# 添加账户
add_account() {
    while true; do
        echo "添加账户："
        echo "1. 设置账户登录邮箱"
        echo "2. 设置区域ID"
        echo "3. 设置API Key"
        read -p "请选择功能（留空则返回上级）: " choice

        case $choice in
            1) read -p "请输入邮箱: " email ;;
            2) read -p "请输入区域ID: " zone_id ;;
            3) read -p "请输入API Key: " api_key ;;
            "") return ;;
            *) echo "无效选项，请重新选择。" ;;
        esac
    done
}

# 解析地址设置菜单
resolve_settings() {
    while true; do
        echo "解析地址设置："
        echo "1. 添加解析"
        echo "2. 删除解析"
        echo "3. 修改解析"
        echo "4. 查看计划任务"
        read -p "请选择功能（留空则返回上级）: " choice

        case $choice in
            1) add_resolve ;;
            2) remove_resolve ;;
            3) modify_resolve ;;
            4) view_cron_jobs ;;
            "") return ;;
            *) echo "无效选项，请重新选择。" ;;
        esac
    done
}

# 添加解析
add_resolve() {
    read -p "请选择账户（留空则返回上级）: " account
    if [ -z "$account" ]; then return; fi
    
    read -p "请输入要解析的一级域名（留空则返回上级）: " primary_domain
    if [ -z "$primary_domain" ]; then return; fi

    while true; do
        echo "请选择模式（留空则返回上级）："
        echo "1. 多个IP分别解析到多个域名"
        echo "2. 多个IP解析到同一个域名"
        read -p "请选择 (1-2): " mode

        case $mode in
            1)
                read -p "请输入多个二级域名（以空格分开，留空则返回上级）: " subdomains
                ;;
            2)
                read -p "请输入一个二级域名（留空则返回上级）: " subdomain
                ;;
            "") return ;;
            *) echo "无效选项，请重新选择。" ;;
        esac
    done

    read -p "请分别输入IPv4和IPv6地址解析数量（以空格隔开，输入0则不解析，留空则返回上级）: " ip4_count ip6_count
    if [ -z "$ip4_count" ] || [ -z "$ip6_count" ]; then return; fi

    read -p "请输入CloudflareST命令，以“./CloudflareST”开头（留空则返回上级）: " cfst_command
    if [ -z "$cfst_command" ]; then return; fi

    # 保存解析规则
    rule_id=${#resolve_rules[@]}
    resolve_rules[$rule_id]="账户: $account, 域名: $primary_domain, 模式: $mode, CloudflareST命令: $cfst_command, IPv4解析数量: $ip4_count, IPv6解析数量: $ip6_count"
    
    echo "解析规则添加成功，规则ID: $rule_id"
}

# 推送设置菜单
push_settings() {
    while true; do
        echo "推送设置："
        echo "1. Telegram"
        echo "2. Pushplus"
        read -p "请选择推送渠道（留空则返回上级）: " choice

        case $choice in
            1)
                read -p "请输入Telegram Token（留空则返回上级）: " tg_token
                ;;
            2)
                read -p "请输入Pushplus Token（留空则返回上级）: " pp_token
                ;;
            "") return ;;
            *) echo "无效选项，请重新选择。" ;;
        esac
    done
}

# 删除和创建Cloudflare解析记录
cloudflare_dns_update() {
    local zone_id=$1
    local auth_email=$2
    local api_key=$3
    local domain=$4
    local ipv4=$5
    local ipv6=$6

    # 删除现有的域名解析记录
    echo "删除 $domain 的现有解析记录..."
    curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=A&name=$domain" \
        -H "X-Auth-Email: $auth_email" \
        -H "X-Auth-Key: $api_key" \
        -H "Content-Type: application/json"
    curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=AAAA&name=$domain" \
        -H "X-Auth-Email: $auth_email" \
        -H "X-Auth-Key: $api_key" \
        -H "Content-Type: application/json"

    # 创建新的 A 记录
    if [ -n "$ipv4" ]; then
        echo "创建新的 A 记录..."
        curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
            -H "X-Auth-Email: $auth_email" \
            -H "X-Auth-Key: $api_key" \
            -H "Content-Type: application/json" \
            --data '{
                "type":"A",
                "name":"'"$domain"'",
                "content":"'"$ipv4"'",
                "ttl":120,
                "proxied":false
            }'
    fi

    # 创建新的 AAAA 记录
    if [ -n "$ipv6" ]; then
        echo "创建新的 AAAA 记录..."
        curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
            -H "X-Auth-Email: $auth_email" \
            -H "X-Auth-Key: $api_key" \
            -H "Content-Type: application/json" \
            --data '{
                "type":"AAAA",
                "name":"'"$domain"'",
                "content":"'"$ipv6"'",
                "ttl":120,
                "proxied":false
            }'
    fi
}

# 执行解析
execute_resolve() {
    if [ ${#resolve_rules[@]} -eq 0 ]; then
        echo "暂无解析规则。"
        return
    fi

    echo "已设置的解析规则："
    for rule_id in "${!resolve_rules[@]}"; do
        echo "[$rule_id] ${resolve_rules[$rule_id]}"
    done

    read -p "请选择要执行的解析规则ID（留空则返回上级）: " rule_id
    if [ -z "$rule_id" ]; then return; fi

    rule=${resolve_rules[$rule_id]}
    echo "执行规则: $rule"
    
    # 执行网络检测
    check_network_support

    # 使用CloudflareST测试并上传解析结果
    cloudflare_dns_update "$zone_id" "$auth_email" "$api_key" "$primary_domain" "$IPV4" "$IPV6"
}

main_menu
