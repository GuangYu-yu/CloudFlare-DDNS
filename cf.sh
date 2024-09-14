#!/bin/bash

# 全局变量：用于存储网络状态
ipv6_status=""
ipv4_status=""

# 检测cf.yaml文件
if [ ! -f "cf.yaml" ]; then
    touch cf.yaml
fi

config_file=cf.yaml

TIMEOUT=5    # 默认超时时间
RETRY_LIMIT=10 # 默认最大重试次数

# 检测单个网络协议
detect_protocol() {
    local protocol=$1
    local urls=("${!2}")
    local timeout=$3
    local retry=$4
    local pids=()
    local attempt=0

    # 开始重试逻辑
    while [ $attempt -lt $retry ]; do
        echo "尝试第 $((attempt + 1)) 次检测 (协议: IPv$protocol)"
        pids=()

        # 并发检测 URL
        for url in "${urls[@]}"; do
            curl -s"$protocol" --connect-timeout $timeout "https://$url" > /dev/null &
            pids+=($!)
        done

        # 等待任意一个请求成功
        for pid in "${pids[@]}"; do
            if wait $pid; then
                return 0  # 成功
            fi
        done

        # 增加尝试次数
        attempt=$((attempt + 1))
    done

    return 1  # 全部尝试失败
}

# 通用检测函数
check_network_status() {
    local protocol=$1
    local status_var_name=$2
    local urls=("${!3}")
    local timeout=$4
    local retry=$5

    if detect_protocol $protocol urls[@] $timeout $retry; then
        eval "$status_var_name='√'"
    else
        eval "$status_var_name='×'"
    fi
}

# 检测 IPv6 和 IPv4 状态
detect_ip_addresses() {

    # 定义检测的 URL 列表（各个URL必须同时支持IPv4和IPv6）
    urls=("ifconfig.co" "whatismyipaddress.info" "cdnjs.cloudflare.com" "whatismyipaddress.com" "iplocation.io" "whatismyip.com" "ipaddress.my" "iplocation.net" "ipqualityscore.com" "ip.sb")

    # 检测 IPv6 和 IPv4
    check_network_status 6 ipv6_status urls[@] $TIMEOUT $RETRY_LIMIT
    check_network_status 4 ipv4_status urls[@] $TIMEOUT $RETRY_LIMIT
}

# 显示网络状态
display_network_status() {
    # 使用 \r 清除上一行内容，保持输出行刷新
    echo -e "\rIPv6 状态: $ipv6_status         IPv4 状态: $ipv4_status"
}

# 刷新网络状态
refresh_network_status() {
    echo "正在检测网络..."
    detect_ip_addresses
}

# 运行检测
refresh_network_status

# 主菜单
main_menu() {
    
    while true; do
        clear
        echo "================================="
        echo "             主菜单"
        echo "================================="
        
        # 显示当前网络状态
        display_network_status

        echo "================================="
        echo "1. 设置账户"
        echo "2. 解析地址"
        echo "3. 推送设置"
        echo "4. 执行解析"
        echo "5. 刷新网络"
        echo "6. 退出"
        echo "================================="
        read -p "请选择 (1-6): " choice

        case $choice in
            1) account_settings ;;
            2) resolve_settings ;;
            3) push_settings ;;
            4) execute_resolve ;;
            5) refresh_network_status ;;  # 选择刷新网络状态
            6) exit 0 ;;
            *) continue ;;
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
        echo "已设置的账户信息："

    # 使用 awk 输出已存在的账户信息
    awk -F' ' '{for (i=1; i<=NF; i++) { split($i, a, "="); if (a[1] == "account_group") printf "账户组: %s ", a[2]; else if (a[1] == "x_email") printf "邮箱: %s ", a[2]; else if (a[1] == "zone_id") printf "区域ID: %s ", a[2]; else if (a[1] == "api_key") printf "API Key: %s ", a[2]; }
        print "";
    }' $config_file

        echo "================================="
        echo "1. 添加账户"
        echo "2. 删除账户"
        echo "3. 修改账户"
        echo "4. 返回主菜单"
        echo "================================="
        read -p "请选择 (1-4): " choice

        case $choice in
            1) add_account ;;
            2) delete_account ;;
            3) modify_account ;;
            4) return ;;
            *) continue ;;
        esac
    done
}

# 添加账户
add_account() {
    clear
    echo "================================="
    echo "           添加账户"
    echo "================================="
    
    read -p "请输入自定义账户组名称（只能包含字母、数字和下划线）：" account_group

    # 验证账户组名称
    while ! [[ "$account_group" =~ ^[A-Za-z0-9_]+$ ]]; do
        echo "账户组名称格式不正确，请重新输入。"
        read -p "请输入自定义账户组名称（只能包含字母、数字和下划线）：" account_group
    done

    read -p "请输入账户登陆邮箱：" x_email

    # 验证邮箱格式
    while ! [[ "$x_email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; do
        echo "邮箱格式不正确，请重新输入。"
        read -p "请输入账户登陆邮箱：" x_email
    done

    # 输入区域ID，检测不能为空
    read -p "请输入区域ID：" zone_id
    while [[ -z "$zone_id" ]]; do
        echo "区域ID不能为空，请重新输入。"
        read -p "请输入区域ID：" zone_id
    done

    # 输入API Key，检测不能为空
    read -p "请输入API Key：" api_key
    while [[ -z "$api_key" ]]; do
        echo "API Key不能为空，请重新输入。"
        read -p "请输入API Key：" api_key
    done

    # 将账户信息写入配置文件，格式为一行
    echo "account_group=$account_group x_email=$x_email zone_id=$zone_id api_key=$api_key" >> "$config_file"

    echo "账户添加成功！"
    sleep 2
    account_settings
}

# 删除账户
delete_account() {
    clear
    echo "================================="
    echo "           删除账户"
    echo "================================="
    echo "已设置的账户信息："

    # 使用 awk 输出已存在的账户信息
    awk -F' ' '{for (i=1; i<=NF; i++) { split($i, a, "="); if (a[1] == "account_group") printf "账户组: %s ", a[2]; else if (a[1] == "x_email") printf "邮箱: %s ", a[2]; else if (a[1] == "zone_id") printf "区域ID: %s ", a[2]; else if (a[1] == "api_key") printf "API Key: %s ", a[2]; }
        print "";
    }' $config_file

    echo "================================="
    read -p "请输入要删除的账户组名称（留空则返回上级）：" delete_group

    if [ -z "$delete_group" ]; then
        return
    fi

    # 检查账户组名称是否存在
    if ! grep -q "^account_group=$delete_group " "$config_file"; then
        echo "不存在该账户组名称！"
        sleep 2
        delete_account
        return
    fi

    # 删除指定账户组的相关信息
    sed -i "/^account_group=$delete_group /,/^account_group=/d" "$config_file"

    echo "账户组 $delete_group 已成功删除！"
    sleep 2
    account_settings
}

# 修改账户
modify_account() {
    clear
    echo "================================="
    echo "           修改账户"
    echo "================================="
    echo "已设置的账户信息："
    
    # 使用 awk 输出已存在的账户信息
    awk -F' ' '{for (i=1; i<=NF; i++) { split($i, a, "="); if (a[1] == "account_group") printf "账户组: %s ", a[2]; else if (a[1] == "x_email") printf "邮箱: %s ", a[2]; else if (a[1] == "zone_id") printf "区域ID: %s ", a[2]; else if (a[1] == "api_key") printf "API Key: %s ", a[2]; }
    print "";
    }' $config_file

    echo "================================="
    read -p "请输入要修改的账户组（留空则返回上级）：" modify_account_group
    if [ -z "$modify_account_group" ]; then
        return
    fi

    # 提示用户选择要修改的内容
    while true; do
        echo "请选择要修改的内容："
        echo "1. 账户登陆邮箱"
        echo "2. 区域ID"
        echo "3. API Key"
        echo "4. 退出"
        read -p "请输入选项 (1-4)：" choice

        case $choice in
            1)  read -p "请输入新的账户登陆邮箱：" new_email
                # 验证邮箱格式
                if [[ -z "$new_email" ]]; then
                    echo "输入不能为空，请重新输入"
                elif ! [[ "$new_email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
                    echo "邮箱格式不正确，请重新输入"
                else
                    sed -i "s/^x_email=.*/x_email=$new_email/" $config_file
                    echo "邮箱已更新"
                fi ;;
            2)  read -p "请输入新的区域ID：" new_region_id
                if [[ -z "$new_region_id" ]]; then
                    echo "输入不能为空，请重新输入"
                else
                    sed -i "s/^zone_id=.*/zone_id=$new_region_id/" $config_file
                    echo "区域ID已更新"
                fi ;;
            3)  read -p "请输入新的API Key：" new_api_key
                if [[ -z "$new_api_key" ]]; then
                    echo "输入不能为空，请重新输入"
                else
                    sed -i "s/^api_key=.*/api_key=$new_api_key/" $config_file
                    echo "API Key已更新"
                fi ;;
            4)  break ;;
            *)  modify_account ;;
                
        esac
    done

    echo "账户信息修改完毕。"
    sleep 2
    account_settings
}

# 解析设置
resolve_settings() {
    while true; do
        clear
        echo "================================="
        echo "           解析设置"
        echo "================================="
        echo "1. 添加解析"
        echo "2. 删除解析"
        echo "3. 修改解析"
        echo "4. 查看计划任务"
        echo "5. 返回主菜单"
        echo "================================="
        read -p "请选择 (1-5): " choice

        case $choice in
            1) add_resolve ;;
            2) delete_resolve ;;
            3) modify_resolve ;;
            4) view_schedule ;;
            5) return ;;
            *) continue ;;
        esac
    done
}

# 添加解析
add_resolve() {
    clear
    echo "================================="
    echo "           添加解析"
    echo "================================="
    read -p "请选择账户 （留空则返回上级）：" account
    if [ -z "$account" ]; then
        return
    fi

    read -p "请输入要解析的一级域名（留空则返回上级）：" domain
    if [ -z "$domain" ]; then
        return
    fi

    echo "请选择模式（留空则返回上级）："
    echo "1. 多个IP分别解析到多个域名"
    echo "2. 多个IP解析到同一个域名"
    read -p "请选择 (1-2): " mode

    case $mode in
        1) add_resolve_multi ;;
        2) add_resolve_single ;;
        *) return ;;
    esac
}

# 多个IP分别解析到多个域名
add_resolve_multi() {
    clear
    echo "================================="
    echo "           多个IP分别解析到多个域名"
    echo "================================="
    read -p "请输入多个二级域名（不含一级域名，以空格分开，留空则返回上级）：" subdomains
    if [ -z "$subdomains" ]; then
        return
    fi

    process_resolve
}

# 多个IP解析到同一个域名
add_resolve_single() {
    clear
    echo "================================="
    echo "           多个IP解析到同一个域名"
    echo "================================="
    read -p "请输入一个二级域名（不含一级域名，留空则返回上级）：" subdomain
    if [ -z "$subdomain" ]; then
        return
    fi

    process_resolve
}

# 处理解析设置的通用函数
process_resolve() {
    clear
    echo "================================="
    echo "           解析设置"
    echo "================================="
    read -p "请分别输入IPv4和IPv6地址解析数量（以空格隔开，输入0则不解析，留空则返回上级）：" ipv4_count ipv6_count
    if [ -z "$ipv4_count" ] || [ -z "$ipv6_count" ]; then
        return
    fi

    read -p "请输入CloudflareST命令，以“./CloudflareST”开头（不包含引号，留空则返回上级）：" cf_command
    if [ -z "$cf_command" ]; then
        return
    fi

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
    echo "    -httping"
    echo "        切换测速模式；延迟测速模式改为 HTTP 协议，所用测试地址为 [-url] 参数；(默认 TCPing)"
    echo "    -httping-code 200"
    echo "        有效状态代码；HTTPing 延迟测速时网页返回的有效 HTTP 状态码，仅限一个；(默认 200 301 302)"
    echo "    -tl 200"
    echo "        平均延迟上限；只输出低于指定平均延迟的 IP，各上下限条件可搭配使用；(默认 9999 ms)"
    echo "    -tll 40"
    echo "        平均延迟下限；只输出高于指定平均延迟的 IP；(默认 0 ms)"
    echo "    -tlr 0.2"
    echo "        丢包几率上限；只输出低于/等于指定丢包率的 IP，范围 0.00~1.00，0 过滤掉任何丢包的 IP；(默认 1.00)"
    echo "    -sl 5"
    echo "        下载速度下限；只输出高于指定下载速度的 IP，凑够指定数量 [-dn] 才会停止测速；(默认 0.00 MB/s)"
    echo "    -p 10"
    echo "        显示结果数量；测速后直接显示指定数量的结果，为 0 时不显示结果直接退出；(默认 10 个)"
    echo "    -dd"
    echo "        禁用下载测速；禁用后测速结果会按延迟排序 (默认按下载速度排序)；(默认 启用)"

    read -p "请输入IPv4地址URL（留空则重新输入）：" ipv4_url
    read -p "请输入IPv6地址URL（留空则重新输入）：" ipv6_url

    if [ -n "$ipv4_url" ] && [ "$ipv4_count" -gt 0 ]; then
        curl -s "$ipv4_url" > ip4.txt
        cf_command="$cf_command -f ip4.txt"
    fi

    if [ -n "$ipv6_url" ] && [ "$ipv6_count" -gt 0 ]; then
        curl -s "$ipv6_url" > ip6.txt
        cf_command="$cf_command -f ip6.txt"
    fi

    echo "解析设置完成。"
    sleep 2
    resolve_settings
}

# 删除解析
delete_resolve() {
    clear
    echo "================================="
    echo "           删除解析"
    echo "================================="
    echo "已设置的解析信息："
    awk -F'=' '{if ($1 == "domain") print "域名: " $2; else if ($1 == "subdomain") print "二级域名: " $2; else if ($1 == "ipv4_count") print "IPv4解析数量: " $2; else if ($1 == "ipv6_count") print "IPv6解析数量: " $2; else if ($1 == "cf_command") print "CloudflareST命令: " $2}' $config_file
    echo "================================="
    read -p "请输入要删除的解析域名（留空则返回上级）：" delete_domain
    if [ -z "$delete_domain" ]; then
        return
    fi

    # 删除配置文件中的解析信息
    sed -i "/^domain=$delete_domain/d" $config_file
    sed -i "/^subdomain=/d" $config_file
    sed -i "/^ipv4_count=/d" $config_file
    sed -i "/^ipv6_count=/d" $config_file
    sed -i "/^cf_command=/d" $config_file

    echo "解析已删除。"
    sleep 2
    resolve_settings
}

# 修改解析
modify_resolve() {
    clear
    echo "================================="
    echo "           修改解析"
    echo "================================="
    echo "已设置的解析信息："
    awk -F'=' '{if ($1 == "domain") print "域名: " $2; else if ($1 == "subdomain") print "二级域名: " $2; else if ($1 == "ipv4_count") print "IPv4解析数量: " $2; else if ($1 == "ipv6_count") print "IPv6解析数量: " $2; else if ($1 == "cf_command") print "CloudflareST命令: " $2}' $config_file
    echo "================================="
    read -p "请输入要修改的解析域名（留空则返回上级）：" modify_domain
    if [ -z "$modify_domain" ]; then
        return
    fi

    read -p "请输入新的二级域名（留空则不修改）：" new_subdomain
    read -p "请输入新的IPv4解析数量（留空则不修改）：" new_ipv4_count
    read -p "请输入新的IPv6解析数量（留空则不修改）：" new_ipv6_count
    read -p "请输入新的CloudflareST命令（留空则不修改）：" new_cf_command

    # 更新配置文件中的解析信息
    if [ -n "$new_subdomain" ]; then
        sed -i "s/^subdomain=.*/subdomain=$new_subdomain/" $config_file
    fi
    if [ -n "$new_ipv4_count" ]; then
        sed -i "s/^ipv4_count=.*/ipv4_count=$new_ipv4_count/" $config_file
    fi
    if [ -n "$new_ipv6_count" ]; then
        sed -i "s/^ipv6_count=.*/ipv6_count=$new_ipv6_count/" $config_file
    fi
    if [ -n "$new_cf_command" ]; then
        sed -i "s/^cf_command=.*/cf_command=$new_cf_command/" $config_file
    fi

    echo "解析信息已更新。"
    sleep 2
    resolve_settings
}

# 查看计划任务
view_schedule() {
    clear
    echo "================================="
    echo "           查看计划任务"
    echo "================================="
    echo "已设置的解析信息："
    awk -F'=' '{if ($1 == "domain") print "域名: " $2; else if ($1 == "subdomain") print "二级域名: " $2; else if ($1 == "ipv4_count") print "IPv4解析数量: " $2; else if ($1 == "ipv6_count") print "IPv6解析数量: " $2; else if ($1 == "cf_command") print "CloudflareST命令: " $2}' $config_file
    echo "================================="
    read -p "请输入要查看计划任务的解析域名（留空则返回上级）：" view_domain
    if [ -z "$view_domain" ]; then
        return
    fi

    # 读取配置文件中的解析信息
    domain=$(grep "^domain=$view_domain" $config_file | cut -d'=' -f2)
    subdomain=$(grep "^subdomain=" $config_file | cut -d'=' -f2)
    ipv4_count=$(grep "^ipv4_count=" $config_file | cut -d'=' -f2)
    ipv6_count=$(grep "^ipv6_count=" $config_file | cut -d'=' -f2)
    cf_command=$(grep "^cf_command=" $config_file | cut -d'=' -f2)

    # 显示计划任务示例
    echo "================================="
    echo "计划任务示例："
    echo "1. 每天4点更新一次"
    echo "2. 每6小时更新一次"
    echo "================================="
    read -p "请选择计划任务示例 (1-2): " schedule_choice

    case $schedule_choice in
        1) schedule_cron="0 4 * * *" ;;
        2) schedule_cron="0 */6 * * *" ;;
        *) echo "无效选项，请重新选择。" ;;
    esac

    # 生成计划任务
    echo "计划任务："
    echo "$schedule_cron $cf_command"
    echo "================================="
    read -p "按任意键返回上级菜单..." -n1 -s
    resolve_settings
}

# 推送设置
push_settings() {
    while true; do
        clear
        echo "================================="
        echo "           推送设置"
        echo "================================="
        echo "1. 设置Telegram推送"
        echo "2. 设置PushPlus推送"
        echo "3. 设置Server 酱推送"
        echo "4. 设置PushDeer推送"
        echo "5. 设置企业微信推送"
        echo "6. 设置Synology Chat推送"
        echo "7. 返回主菜单"
        echo "================================="
        read -p "请选择 (1-7): " choice

        case $choice in
            1) set_telegram_push ;;
            2) set_pushplus_push ;;
            3) set_server_push ;;
            4) set_pushdeer_push ;;
            5) set_wechat_push ;;
            6) set_synology_chat_push ;;
            7) return ;;
            *) echo "无效选项，请重新选择。" ;;
        esac
    done
}

# 设置Telegram推送
set_telegram_push() {
    clear
    echo "================================="
    echo "           设置Telegram推送"
    echo "================================="
    read -p "请输入Telegram Bot Token（留空则返回上级）：" telegram_bot_token
    if [ -z "$telegram_bot_token" ]; then
        return
    fi

    read -p "请输入Telegram User ID（留空则返回上级）：" telegram_user_id
    if [ -z "$telegram_user_id" ]; then
        return
    fi

    # 将Telegram推送信息写入配置文件
    echo "telegram_bot_token=$telegram_bot_token" >> $config_file
    echo "telegram_user_id=$telegram_user_id" >> $config_file

    echo "Telegram推送设置成功！"
    sleep 2
    push_settings
}

# 设置PushPlus推送
set_pushplus_push() {
    clear
    echo "================================="
    echo "           设置PushPlus推送"
    echo "================================="
    read -p "请输入PushPlus Token（留空则返回上级）：" pushplus_token
    if [ -z "$pushplus_token" ]; then
        return
    fi

    # 将PushPlus推送信息写入配置文件
    echo "pushplus_token=$pushplus_token" >> $config_file

    echo "PushPlus推送设置成功！"
    sleep 2
    push_settings
}

# 设置Server 酱推送
set_server_push() {
    clear
    echo "================================="
    echo "           设置Server 酱推送"
    echo "================================="
    read -p "请输入Server 酱 SendKey（留空则返回上级）：" server_sendkey
    if [ -z "$server_sendkey" ]; then
        return
    fi

    # 将Server 酱推送信息写入配置文件
    echo "server_sendkey=$server_sendkey" >> $config_file

    echo "Server 酱推送设置成功！"
    sleep 2
    push_settings
}

# 设置PushDeer推送
set_pushdeer_push() {
    clear
    echo "================================="
    echo "           设置PushDeer推送"
    echo "================================="
    read -p "请输入PushDeer PushKey（留空则返回上级）：" pushdeer_pushkey
    if [ -z "$pushdeer_pushkey" ]; then
        return
    fi

    # 将PushDeer推送信息写入配置文件
    echo "pushdeer_pushkey=$pushdeer_pushkey" >> $config_file

    echo "PushDeer推送设置成功！"
    sleep 2
    push_settings
}

# 设置企业微信推送
set_wechat_push() {
    clear
    echo "================================="
    echo "           设置企业微信推送"
    echo "================================="
    read -p "请输入企业微信CorpID（留空则返回上级）：" wechat_corpid
    if [ -z "$wechat_corpid" ]; then
        return
    fi

    read -p "请输入企业微信Secret（留空则返回上级）：" wechat_secret
    if [ -z "$wechat_secret" ]; then
        return
    fi

    read -p "请输入企业微信AgentID（留空则返回上级）：" wechat_agentid
    if [ -z "$wechat_agentid" ]; then
        return
    fi

    read -p "请输入企业微信UserID（留空则返回上级）：" wechat_userid
    if [ -z "$wechat_userid" ]; then
        return
    fi

    # 将企业微信推送信息写入配置文件
    echo "wechat_corpid=$wechat_corpid" >> $config_file
    echo "wechat_secret=$wechat_secret" >> $config_file
    echo "wechat_agentid=$wechat_agentid" >> $config_file
    echo "wechat_userid=$wechat_userid" >> $config_file

    echo "企业微信推送设置成功！"
    sleep 2
    push_settings
}

# 设置Synology Chat推送
set_synology_chat_push() {
    clear
    echo "================================="
    echo "           设置Synology Chat推送"
    echo "================================="
    read -p "请输入Synology Chat URL（留空则返回上级）：" synology_chat_url
    if [ -z "$synology_chat_url" ]; then
        return
    fi

    # 将Synology Chat推送信息写入配置文件
    echo "synology_chat_url=$synology_chat_url" >> $config_file

    echo "Synology Chat推送设置成功！"
    sleep 2
    push_settings
}

# 执行解析
execute_resolve() {
    clear
    echo "================================="
    echo "           执行解析"
    echo "================================="
    echo "已设置的解析信息："
    awk -F'=' '{if ($1 == "domain") print "域名: " $2; else if ($1 == "subdomain") print "二级域名: " $2; else if ($1 == "ipv4_count") print "IPv4解析数量: " $2; else if ($1 == "ipv6_count") print "IPv6解析数量: " $2; else if ($1 == "cf_command") print "CloudflareST命令: " $2}' $config_file
    echo "================================="
    read -p "请确认是否执行解析（y/n）：" confirm
    if [ "$confirm" != "y" ]; then
        return
    fi

    # 执行CloudflareST命令
    eval "$(grep "^cf_command=" $config_file | cut -d'=' -f2)"

    echo "解析执行完成。"
    sleep 2
    main_menu
}

# DDNS到Cloudflare
ddns_to_cloudflare() {
    # 获取配置信息
    x_email=$(yq eval ".x_email" $config_file)
    zone_id=$(yq eval ".zone_id" $config_file)
    api_key=$(yq eval ".api_key" $config_file)
    domains=$(yq eval ".domains" $config_file)
    subdomains=$(yq eval ".subdomains" $config_file)
    ipv4_count=$(yq eval ".ipv4_count" $config_file)
    ipv6_count=$(yq eval ".ipv6_count" $config_file)
    cf_command=$(yq eval ".cf_command" $config_file)

    # 验证配置信息
    if [ -z "$x_email" ] || [ -z "$zone_id" ] || [ -z "$api_key" ] || [ -z "$domains" ] || [ -z "$subdomains" ] || [ -z "$ipv4_count" ] || [ -z "$ipv6_count" ] || [ -z "$cf_command" ]; then
        echo "配置信息不完整，请检查配置文件。"
        return 1
    fi

    # 执行CloudflareST获取IP测速结果
    echo "正在执行CloudflareST获取IP测速结果..."
    $cf_command

    # 处理每个域名和二级域名
    IFS=',' read -r -a domain_array <<< "$domains"
    IFS=',' read -r -a subdomain_array <<< "$subdomains"

    for domain in "${domain_array[@]}"; do
        for subdomain in "${subdomain_array[@]}"; do
            CDNhostname="${subdomain}.${domain}"
            echo "正在更新域名：$CDNhostname"

            # 获取测速结果文件
            if [ "$ipv4_count" -gt 0 ]; then
                csvfile="result.csv"
            elif [ "$ipv6_count" -gt 0 ]; then
                csvfile="result_ipv6.csv"
            else
                echo "未指定IPv4或IPv6解析数量。"
                continue
            fi

            # 如果没有生成对应结果文件，跳过
            if [ ! -e $csvfile ]; then
                echo "未找到测速结果文件：$csvfile"
                continue
            fi

            # 读取测速结果文件并更新DNS记录
            lineNo=0
            ipcount=0
            while read -r line; do
                ((lineNo++))
                if ((lineNo == 1)); then
                    continue
                fi
                IFS=, read -ra fields <<<"$line"
                ipAddr=${fields[0]}

                ((ipcount++))
                echo "开始更新第${ipcount}个---$ipAddr"
                UpInsetCF $ipAddr

                if ((ipcount >= ipv4_count + ipv6_count)); then
                    break
                fi
            done <$csvfile

            echo "完成$CDNhostname的IP更新!"
        done
    done

    # 测速完毕
    echo "测速完毕"
    if [ "$pause" = "false" ]; then
        echo "按要求未重启科学上网服务"
        sleep 3s
    else
        /etc/init.d/$CLIEN restart
        echo "已重启$CLIEN"
        echo "为保证cloudflareAPI连接正常 将在3秒后开始更新域名解析"
        sleep 3s
    fi

    # 调用ddns_to_cloudflare函数
    ddns_to_cloudflare

    # 推送消息
    pushmessage=$(cat informlog)
    echo $pushmessage

    if [ ! -z "$sendType" ]; then
        if [[ $sendType -eq 1 ]]; then
            source ./msg/cf_push
        elif [[ $sendType -eq 2 ]]; then
            source ./msg/wxsend_jiang.sh
        elif [[ $sendType -eq 3 ]]; then
            source ./msg/cf_push
            source ./msg/wxsend_jiang.sh
        else
            echo "$sendType is invalid type!"
        fi
    fi
    echo "所有域名更新完成！"
}

# 主程序入口
main_menu
