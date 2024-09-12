#!/bin/bash

# 配置文件路径
config_file="config.cfg"

# 显示网络支持状态
detect_ip_addresses() {
    echo "检测外网 IP 支持情况..."
    IPV4=$(curl -s4 ifconfig.co || curl -s4 ipinfo.io || curl -s4 api64.ipify.org || curl -s4 test.ipw.cn)
    IPV6=$(curl -s6 ifconfig.co || curl -s6 ipinfo.io || curl -s6 api64.ipify.org || curl -s6 test.ipw.cn)

    if [[ -n "$IPV4" ]]; then
        echo "IPv4:√"
    else
        echo "IPv4:×"
    fi

    if [[ -n "$IPV6" ]]; then
        echo "IPv6:√"
    else
        echo "IPv6:×"
    fi
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo "================================="
        echo "           主菜单"
        echo "================================="
        detect_ip_addresses
        echo ""
        echo "1. 设置账户"
        echo "2. 解析地址"
        echo "3. 推送设置"
        echo "4. 执行解析"
        echo "5. 退出"
        echo "================================="
        read -p "请选择 (1-5): " choice

        case $choice in
            1) account_settings ;;
            2) resolve_settings ;;
            3) set_push ;;
            4) execute_resolve ;;
            5) exit 0 ;;
            *) echo "无效选项，请重新选择。" ;;
        esac
    done
}

# 账户设置
account_settings() {
    while true; do
        clear
        echo "================================="
        echo "           账户设置"
        echo "================================="
        echo "1. 添加账户"
        echo "2. 删除账户"
        echo "3. 修改账户"
        echo "4. 查看账户列表"
        echo "================================="
        read -p "请选择功能（留空则返回上级）: " choice

        case $choice in
            1) add_account ;;
            2) remove_account ;;
            3) modify_account ;;
            4) show_accounts ;;
            "") return ;;
            *) echo "无效选项，请重新选择。" ;;
        esac
    done
}

# 添加账户
add_account() {
    while true; do
        clear
        echo "================================="
        echo "           添加账户"
        echo "================================="
        echo "1. 设置账户登录邮箱"
        echo "2. 设置区域ID"
        echo "3. 设置API Key"
        echo "================================="
        read -p "请选择功能（留空则返回上级）: " choice

        case $choice in
            1) read -p "请输入账户登录邮箱: " email ;;
            2) read -p "请输入区域ID: " zone_id ;;
            3) read -p "请输入API Key: " api_key ;;
            "") return ;;
            *) echo "无效选项，请重新选择。" ;;
        esac

        # 保存到配置文件
        if [[ -n "$email" ]]; then
            echo "email=$email" >> "$config_file"
        fi
        if [[ -n "$zone_id" ]]; then
            echo "zone_id=$zone_id" >> "$config_file"
        fi
        if [[ -n "$api_key" ]]; then
            echo "api_key=$api_key" >> "$config_file"
        fi

        echo "账户信息已保存。"
    done
}

# 删除账户
remove_account() {
    echo "================================="
    echo "          删除账户"
    echo "================================="
    # 读取所有账户
    accounts=($(grep -oP 'email=\K[^=]+' "$config_file"))

    if [[ ${#accounts[@]} -eq 0 ]]; then
        echo "没有找到任何账户记录。"
        return
    fi

    echo "现有账户记录:"
    for i in "${!accounts[@]}"; do
        echo "$i. ${accounts[i]}"
    done

    read -p "请选择要删除的账户编号（留空则返回上级）: " account_choice

    if [[ -z $account_choice || $account_choice -ge ${#accounts[@]} ]]; then
        echo "无效选择或未选择，返回上级。"
        return
    fi

    account_to_remove="${accounts[account_choice]}"

    # 从配置文件中删除选定账户
    sed -i "/email=$account_to_remove/d" "$config_file"

    echo "账户 '$account_to_remove' 已删除。"
}

# 修改账户
modify_account() {
    echo "================================="
    echo "          修改账户"
    echo "================================="
    # 读取所有账户
    accounts=($(grep -oP 'email=\K[^=]+' "$config_file"))

    if [[ ${#accounts[@]} -eq 0 ]]; then
        echo "没有找到任何账户记录。"
        return
    fi

    echo "现有账户记录:"
    for i in "${!accounts[@]}"; do
        echo "$i. ${accounts[i]}"
    done

    read -p "请选择要修改的账户编号（留空则返回上级）: " account_choice

    if [[ -z $account_choice || $account_choice -ge ${#accounts[@]} ]]; then
        echo "无效选择或未选择，返回上级。"
        return
    fi

    account_to_modify="${accounts[account_choice]}"

    echo "将要修改的账户: $account_to_modify"
    read -p "请输入新的邮箱（留空则保持不变）: " new_email

    if [[ -n "$new_email" ]]; then
        # 从配置文件中删除旧账户
        sed -i "/email=$account_to_modify/d" "$config_file"
        echo "email=$new_email" >> "$config_file"
        echo "账户信息已更新。"
    else
        echo "邮箱为空，未修改。"
    fi
}

# 显示账户列表
show_accounts() {
    echo "================================="
    echo "          账户列表"
    echo "================================="
    if [[ ! -f $config_file ]]; then
        echo "配置文件不存在。"
        return
    fi

    # 获取账户信息
    accounts=$(grep -E 'email=' "$config_file" | sed 's/email=//')

    if [[ -z $accounts ]]; then
        echo "没有账户记录。"
        return
    fi

    echo "现有账户记录:"
    echo "$accounts"
}

# 解析地址设置
resolve_settings() {
    while true; do
        clear
        echo "================================="
        echo "       解析地址设置"
        echo "================================="
        echo "1. 添加解析"
        echo "2. 删除解析"
        echo "3. 修改解析"
        echo "4. 查看计划任务"
        echo "================================="
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
    while true; do
        clear
        echo "================================="
        echo "           添加解析"
        echo "================================="
        read -p "请选择账户（留空则返回上级）: " account

        read -p "请输入要解析的一级域名（留空则返回上级）: " primary_domain

        echo "请选择模式（留空则返回上级）:"
        echo "1. 多个IP分别解析到多个域名"
        echo "2. 多个IP解析到同一个域名"
        read -p "请选择模式: " mode

        case $mode in
            1) read -p "请输入多个二级域名（不含一级域名，以空格分开，留空则返回上级）: " sub_domains ;;
            2) read -p "请输入一个二级域名（不含一级域名，留空则返回上级）: " sub_domain ;;
            *) echo "无效选项，请重新选择。" ;;
        esac

        read -p "请分别输入IPv4和IPv6地址解析数量（以空格隔开，输入0则不解析，留空则返回上级）: " ipv4_count ipv6_count
        read -p "请输入CloudflareST命令，以‘./CloudflareST’开头（不包含引号，留空则返回上级）: " cf_command

        # 显示参数
        echo "参数："
        echo "    -n 200"
        echo "        延迟测速线程；越多延迟测速越快，性能弱的设备 (如路由器) 请勿太高；(默认 200 最多 1000)"
        echo "    -t 4"
        echo "        延迟测速次数；单个 IP 延迟测速的次数；(默认 4 次)"
        echo "    -dn 10"
        echo "        下载测速数量；延迟测速并排序后，从最低延迟起下载测速的数量；(默认 10 个)"
        echo "    -dt 10"
        echo "        下载测速时间；单个 IP 下载测速最长时间，不能太短；(默认 10 秒)"
        echo "    -tp 443"
        echo "        指定测速端口；延迟测速/下载测速时使用的端口；(默认 443 端口)"
        echo "    -url https://cf.xiu2.xyz/url"
        echo "        指定测速地址；延迟测速(HTTPing)/下载测速时使用的地址，默认地址不保证可用性，建议自建；"
        echo ""

        read -p "请输入IPv4地址URL（留空则重新输入）: " ipv4_url
        read -p "请输入IPv6地址URL（留空则重新输入）: " ipv6_url

        # 下载CIDR
        if [[ -n "$ipv4_url" ]]; then
            curl -s "$ipv4_url" -o "ip4.txt"
        fi
        if [[ -n "$ipv6_url" ]]; then
            curl -s "$ipv6_url" -o "ip6.txt"
        fi

        # 根据解析数量执行测速
        if [[ $ipv4_count -gt 0 ]]; then
            # 执行 IPv4 测速
            ./$cf_command -f ip4.txt
        fi
        if [[ $ipv6_count -gt 0 ]]; then
            # 执行 IPv6 测速
            ./$cf_command -f ip6.txt
        fi

        echo "解析已添加。"
    done
}

# 删除解析
remove_resolve() {
    echo "================================="
    echo "          删除解析"
    echo "================================="
    # 读取解析记录
    # 这里假设解析记录保存在一个文件中，您需要根据实际情况调整
    resolve_list=$(cat resolve_list.txt)

    if [[ -z $resolve_list ]]; then
        echo "没有找到解析记录。"
        return
    fi

    echo "现有解析记录:"
    echo "$resolve_list"

    read -p "请选择要删除的解析（留空则返回上级）: " resolve_choice

    if [[ -z $resolve_choice ]]; then
        echo "未选择解析，返回上级。"
        return
    fi

    # 从文件中删除选定解析
    sed -i "/$resolve_choice/d" resolve_list.txt

    echo "解析 '$resolve_choice' 已删除。"
}

# 修改解析
modify_resolve() {
    echo "================================="
    echo "          修改解析"
    echo "================================="
    # 读取解析记录
    # 这里假设解析记录保存在一个文件中，您需要根据实际情况调整
    resolve_list=$(cat resolve_list.txt)

    if [[ -z $resolve_list ]]; then
        echo "没有找到解析记录。"
        return
    fi

    echo "现有解析记录:"
    echo "$resolve_list"

    read -p "请选择要修改的解析（留空则返回上级）: " resolve_choice

    if [[ -z $resolve_choice ]]; then
        echo "未选择解析，返回上级。"
        return
    fi

    # 读取新的解析信息
    read -p "请输入新的一级域名（留空则保持不变）: " new_primary_domain
    read -p "请输入新的二级域名（留空则保持不变）: " new_sub_domain
    read -p "请分别输入新的IPv4和IPv6地址解析数量（以空格隔开，留空则保持不变）: " new_ipv4_count new_ipv6_count

    # 更新解析记录
    # 这里假设解析记录保存在一个文件中，您需要根据实际情况调整
    sed -i "/$resolve_choice/d" resolve_list.txt

    echo "新的解析记录："
    echo "$new_primary_domain $new_sub_domain $new_ipv4_count $new_ipv6_count" >> resolve_list.txt

    echo "解析 '$resolve_choice' 已修改。"
}

# 查看计划任务
view_cron_jobs() {
    echo "================================="
    echo "        查看计划任务"
    echo "================================="
    echo "1. 每天4点运行一次"
    echo "2. 每6小时运行一次"
    echo "================================="
    read -p "请选择计划任务（留空则返回上级）: " choice

    case $choice in
        1) echo "示例：0 4 * * * /path/to/your/script.sh" ;;
        2) echo "示例：0 */6 * * * /path/to/your/script.sh" ;;
        "") return ;;
        *) echo "无效选项，请重新选择。" ;;
    esac
}

# 执行解析
execute_resolve() {
    echo "================================="
    echo "          执行解析"
    echo "================================="
    read -p "请选择账户: " account
    read -p "请选择解析: " resolve

    # 执行解析命令
    ./CloudflareST --resolve "$resolve"

    # 处理测速结果
    results=$(parse_results "results.txt")
    push_token="YOUR_PUSHPLUS_TOKEN"  # 替换为实际的推送 Token
    send_results "$results" "$push_token"
}

# 解析测速结果
parse_results() {
    local results_file=$1
    local results=""

    while IFS= read -r line; do
        if [[ "$line" == IP\ 地址* ]]; then
            continue
        fi

        ip_address=$(echo "$line" | awk '{print $1}')
        sent=$(echo "$line" | awk '{print $2}')
        received=$(echo "$line" | awk '{print $3}')
        packet_loss=$(echo "$line" | awk '{print $4}')
        avg_latency=$(echo "$line" | awk '{print $5}')
        download_speed=$(echo "$line" | awk '{print $6}')

        results+="IP 地址: $ip_address\n已发送: $sent\n已接收: $received\n丢包率: $packet_loss\n平均延迟: $avg_latency\n下载速度: $download_speed MB/s\n\n"
    done < "$results_file"

    echo -e "$results"
}

# 通过推送功能发送结果
send_results() {
    local results=$1
    local token=$2
    local title="测速结果"
    local content="测速结果如下:\n\n$results"

    curl -s -X POST "http://www.pushplus.plus/send" \
        -H "Content-Type: application/json" \
        -d "{
            \"token\": \"$token\",
            \"title\": \"$title\",
            \"content\": \"$content\",
            \"topic\": \"code\",
            \"template\": \"html\"
        }"
}

# 主函数
main() {
    main_menu
}

main
