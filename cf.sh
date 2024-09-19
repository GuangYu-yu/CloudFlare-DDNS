#!/bin/bash

# 全局变量：用于存储网络状态
ipv6_status=""
ipv4_status=""

# 检测 cf.yaml 文件
if [ ! -f "cf.yaml" ]; then
    touch cf.yaml
fi

config_file=cf.yaml

TIMEOUT=3    # 默认超时时间
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
    local status_file=$2
    local urls=("${!3}")
    local timeout=$4
    local retry=$5

    if detect_protocol $protocol urls[@] $timeout $retry; then
        echo "√" > "$status_file"
    else
        echo "×" > "$status_file"
    fi
}

# 检测 IPv6 和 IPv4 状态
detect_ip_addresses() {
    # 定义检测的 URL 列表（各个URL必须同时支持IPv4和IPv6）
    urls=("ifconfig.co" "whatismyipaddress.info" "cdnjs.cloudflare.com" "whatismyipaddress.com" "iplocation.io" "whatismyip.com" "ipaddress.my" "iplocation.net" "ipqualityscore.com" "ip.sb")

    # 临时文件来存储检测结果
    temp_ipv6_status=$(mktemp)
    temp_ipv4_status=$(mktemp)

    # 并发检测 IPv6 和 IPv4
    check_network_status 6 "$temp_ipv6_status" urls[@] $TIMEOUT $RETRY_LIMIT &
    pid_ipv6=$!

    check_network_status 4 "$temp_ipv4_status" urls[@] $TIMEOUT $RETRY_LIMIT &
    pid_ipv4=$!

    # 等待检测完成
    wait $pid_ipv6
    wait $pid_ipv4

    # 从临时文件中读取状态
    ipv6_status=$(cat "$temp_ipv6_status")
    ipv4_status=$(cat "$temp_ipv4_status")

    # 删除临时文件
    rm "$temp_ipv6_status"
    rm "$temp_ipv4_status"
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

# 读取并丢弃所有在缓冲区中的输入
clear_input_buffer() {
    cat /dev/null > /dev/tty
}

# 输出已存在的账户信息
look_account_group() {
    # 使用 sed 提取 account_group, x_email, zone_id, api_key
    sed -n 's/account_group=(\([^)]*\)),x_email=(\([^)]*\)),zone_id=(\([^)]*\)),api_key=(\([^)]*\))/账户组：\1 邮箱：\2 区域ID：\3 API Key：\4/p' "$config_file"
    printf "\n"
}

# 查看解析
look_ddns() {
    awk -F'[=(,) ]+' '
    function get_push_mod(push) {
        mods = ""
        n = split(push, arr, " ")
        err = 0  # 初始化错误标志

        # 遍历每个推送方式并检查是否在0~6范围内
        for (i = 1; i <= n; i++) {
            if (arr[i] == "1") mods = mods "Telegram "
            else if (arr[i] == "2") mods = mods "PushPlus "
            else if (arr[i] == "3") mods = mods "Server酱 "
            else if (arr[i] == "4") mods = mods "PushDeer "
            else if (arr[i] == "5") mods = mods "企业微信 "
            else if (arr[i] == "6") mods = mods "SynologyChat "
            else if (arr[i] == "0") mods = mods "未设置 ";  # 如果arr[i] 为0，则添加"未设置"
            else {
                # 如果有不在0~6范围内的值，标记错误并退出循环
                err = 1
                break
            }
        }

        # 检查错误和返回最终结果
        if (err == 1) return "错误"
        return (mods == "") ? "未设置" : mods
    }

    /add_ddns/ {
        acc = ""; ddns = ""; host1 = ""; host2 = ""; v4 = ""; v6 = ""; cf = ""; v4url = ""; v6url = ""; push = "";
        for (i=1; i<=NF; i++) {
            if ($i == "add_ddns") { acc=$(i+1) }
            if ($i == "ddns_name") { ddns=$(i+1) }
            if ($i == "hostname1") { host1=$(i+1) }
            if ($i == "hostname2") {
                host2 = $(i+1)
                for (j = i+2; j <= NF && $j !~ /^(v4_num|v6_num|cf_command)$/; j++) {
                    host2 = host2 " " $j
                }
            }
            if ($i == "v4_num") { v4=$(i+1) }
            if ($i == "v6_num") { v6=$(i+1) }
            if ($i == "cf_command") {
                cf = $(i+1)
                for (j = i+2; j <= NF && $j !~ /^(v4_url|v6_url|push_mod)$/; j++) {
                    cf = cf " " $j
                }
            }
            if ($i == "v4_url") { v4url=$(i+1) }
            if ($i == "v6_url") { v6url=$(i+1) }
            if ($i == "push_mod") {
                push = $(i+1)
                for (j = i+2; j <= NF && $j !~ /^(add_ddns|ddns_name)$/; j++) {
                    push = push " " $j
                }
            }
        }
        push_mods = get_push_mod(push)
        print "账户组：" acc "\n解析组：" ddns "\n一级域名：" host1 "\n二级域名：" host2 "\nIPv4数量：" v4 "\nIPv6数量：" v6 "\nCloudflareST命令：" cf "\nIPv4地址URL：" v4url "\nIPv6地址URL：" v6url "\n推送方式：" push_mods "\n"
    }
    ' "$config_file"
}

# 只看账户组和解析组
look_ddns_simple() {
    awk -F'[=(,) ]+' '
    /add_ddns/ {
        acc = ""; ddns = "";
        for (i=1; i<=NF; i++) {
            if ($i == "add_ddns") { acc=$(i+1) }
            if ($i == "ddns_name") { ddns=$(i+1) }
        }
        print "账户组：" acc "\n解析组：" ddns "\n"
    }
    ' "$config_file"
}

# CloudflareST命令
look_cfst_rules() {
    echo "    示例：-n 500 -tll 40 -tl 280 -sl 15 -tp 2053"
    echo "    HTTP  端口  80  8080 2052 2082 2086 2095 8880"
    echo "    HTTPS 端口  443 8443 2053 2083 2087 2096 "
    echo "    -n 200      延迟测速线程（最大 1000）"
    echo "    -t 4        延迟测速次数（默认 4 次）"
    echo "    -dt 10      下载测速时间（默认 10 秒）"
    echo "    -tp 443     指定测速端口（默认 443）"
    echo "    -url <URL>  指定测速地址（默认 https://cf.xiu2.xyz/url）"
    echo "    -tl 200     平均延迟上限（默认 9999 ms）"
    echo "    -tll 40     平均延迟下限（默认 0 ms）"
    echo "    -tlr 0.2    丢包几率上限（默认 1.00）"
    echo "    -sl 5       下载速度下限（默认 0.00 MB/s）"
    echo "    -dd         禁用下载测速（默认启用）"
    echo "    -allip      测速全部的IP（仅支持 IPv4,默认每个/24段随机测速一个IP）"
}

# 检查最后一行是否为空行
#    add_blank_line() {
#    if [ -n "$(tail -n 1 "$config_file")" ]; then
#        echo "" >> "$config_file"  # 如果前一行不是空行，插入一个空行
#    fi
#    }

main_menu() {
    local timeout_sec=300  # 设置超时时间，单位为秒

    while true; do
        clear
        echo "================================="
        echo "             主菜单"
        echo "================================="
        
        # 显示当前网络状态
        display_network_status

        echo "================================="
        echo "1. 账户设置"
        echo "2. 解析设置"
        echo "3. 推送设置"
        echo "4. 执行解析"
        echo "5. 刷新网络"
        echo "6. 计划任务"
        echo "7. 插件设置"
        echo "8. 退出"
        echo "================================="
        
        clear_input_buffer
        
        # 使用timeout命令设置超时时间
        read -t $timeout_sec -p "请选择 (1-8): " choice

        # 如果超时，则退出
        if [ $? -ne 0 ]; then
            echo "操作超时，已退出。"
            exit 1
        fi

        case $choice in
            1) account_settings ;;
            2) resolve_settings ;;
            3) push_settings ;;
            4) execute_resolve ;;
            5) refresh_network_status ;;  # 选择刷新网络状态
            6) view_schedule;;
            7) write_plugin_settings;;
            8) exit 0 ;;
            *) : ;;
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

        look_account_group

        echo "================================="
        echo "1. 添加账户"
        echo "2. 删除账户"
        echo "3. 修改账户"
        echo "4. 返回主菜单"
        echo "================================="
        
        clear_input_buffer
        
        read -p "请选择 (1-4): " choice

        case $choice in
            1) add_account ;;
            2) delete_account ;;
            3) modify_account ;;
            4) clear_input_buffer; main_menu ;;
            *) : ;;
        esac
    done
}

# 添加账户
add_account() {
    clear_input_buffer
    clear
    echo "================================="
    echo "           添加账户"
    echo "================================="
    
    while true; do
        read -p "请输入自定义账户组名称（留空则返回上级）：" account_group
        
        if [ -z "$account_group" ]; then
        return
    fi

        if ! [[ "$account_group" =~ ^[A-Za-z0-9_]+$ ]]; then
            echo "账户组名称格式不正确"
            continue
        fi

        if grep -q "account_group=($account_group)" "$config_file"; then
            echo "已有该账户组名称！"
            continue
        fi
        
        break
    done

    read -p "请输入账户登陆邮箱：" x_email
    while ! [[ "$x_email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; do
        echo "邮箱格式不正确"
        read -p "请输入账户登陆邮箱：" x_email
    done

    read -p "请输入区域ID：" zone_id
    while [[ -z "$zone_id" ]]; do
        echo "区域ID不能为空"
        read -p "请输入区域ID：" zone_id
    done

    read -p "请输入API Key：" api_key
    while [[ -z "$api_key" ]]; do
        echo "API Key不能为空"
        read -p "请输入API Key：" api_key
    done


    #add_blank_line
    
    # 写入账户相关信息到配置文件，并使用标识分隔账户部分
    echo "# Account section" >> "$config_file"
    echo "account_group=($account_group),x_email=($x_email),zone_id=($zone_id),api_key=($api_key)" >> "$config_file"

    echo "账户添加成功！"
    sleep 1
    clear_input_buffer
    account_settings
}

# 删除账户
delete_account() {
    clear_input_buffer

    clear
    echo "================================="
    echo "           删除账户"
    echo "================================="
    echo "已设置的账户信息："

    look_account_group

    echo "================================="
    read -p "请输入要删除的账户组名称（留空则返回上级）：" delete_group

    if [ -z "$delete_group" ]; then
        return
    fi

    # 检查账户组名称是否存在
    if ! grep -q "account_group=($delete_group)" "$config_file"; then
        echo "不存在该账户组名称！"
        sleep 1
        delete_account
        return
    fi

    # 确认删除
    read -p "确认删除账户组 $delete_group 吗？(y/n): " confirm_delete
    if [ "$confirm_delete" != "y" ]; then
        echo "取消删除操作。"
        sleep 1
        return
    fi

    # 使用 sed 删除指定的账户组
    sed -i "/^# Account section/{N; /account_group=($delete_group)/{d;}}" "$config_file"

    echo "账户组 $delete_group 成功删除！"
    
    sleep 1

    clear_input_buffer

    account_settings
}

# 修改账户
modify_account() {
    clear
    echo "================================="
    echo "           修改账户"
    echo "================================="
    echo "已设置的账户信息："

    look_account_group

    echo "================================="
    
    update_field() {
    local field="$1"
    local new_value="$2"
    local config_file="$3"
    local account_group="$4"

    sed -i -e "/account_group=($account_group)/{
        s/\($field=(\)[^),]*/\1$new_value/
    }" "$config_file"
}

    
    read -p "请输入要修改的账户组（留空则返回上级）：" modify_account_group
    if [ -z "$modify_account_group" ]; then
        return
    fi
    
    # 检查账户组名称是否存在
    if ! grep -q "account_group=($modify_account_group)" "$config_file"; then
        echo "账户组不存在，请重新输入。"
        sleep 1
        modify_account
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
                    update_field "x_email" "$new_email" "$config_file" "$modify_account_group"
                    echo "邮箱已更新"
                fi ;;
            2)  read -p "请输入新的区域ID：" new_region_id
                if [[ -z "$new_region_id" ]]; then
                    echo "输入不能为空，请重新输入"
                else
                    update_field "zone_id" "$new_region_id" "$config_file" "$modify_account_group"
                    echo "区域ID已更新"
                fi ;;
            3)  read -p "请输入新的API Key：" new_api_key
                if [[ -z "$new_api_key" ]]; then
                    echo "输入不能为空，请重新输入"
                else
                    update_field "api_key" "$new_api_key" "$config_file" "$modify_account_group"
                    echo "API Key已更新"
                fi ;;
            4)  break ;;
            *)  : ;;
        esac
    done

    echo "账户信息修改完毕。"
    sleep 1
    clear_input_buffer
    account_settings
}

# 解析设置
resolve_settings() {
    while true; do
        clear
        echo "================================="
        echo "           解析设置"
        echo "================================="
        
        look_ddns_simple

        echo "================================="
        
        echo "1. 查看解析"
        echo "2. 添加解析"
        echo "3. 删除解析"
        echo "4. 修改解析"
        echo "5. 返回主菜单"
        echo "================================="
        
        read -p "请选择 (1-5): " choice

        case $choice in
            1) view_resolve ;;
            2) add_resolve ;;
            3) delete_resolve ;;
            4) modify_resolve ;;
            5) clear_input_buffer; main_menu ;;
            *) : ;;
        esac
    done
}

# 查看解析
view_resolve() {
    clear
    echo "================================="
    echo "           查看解析"
    echo "================================="

    # 显示该解析组的信息
    look_ddns

    read -p "按回车返回上级"
}

# 添加解析
add_resolve() {
    clear
    echo "================================="
    echo "           添加解析"
    echo "================================="

    look_ddns_simple

    while true; do
        read -p "请输入账户组名称（留空则返回上级）：" add_ddns
        if [ -z "$add_ddns" ]; then
            return
        fi
        
        if ! grep -q "account_group=($add_ddns)" "$config_file"; then
            echo "账户组不存在，请重新输入。"
        else
            break
        fi
    done

    while true; do
        read -p "请输入自定义解析组名称（只能包含字母、数字和下划线）： " ddns_name
        if ! [[ "$ddns_name" =~ ^[A-Za-z0-9_]+$ ]]; then
            echo "解析组名称格式不正确"
            continue
        fi

        if grep -q "ddns_name=($ddns_name)" "$config_file"; then
            echo "已有该解析组名称！"
            continue
        fi
        
        break
    done

    while true; do
        read -p "请输入要解析的一级域名（留空则返回上级）：" hostname1
        if [ -z "$hostname1" ]; then
            return
        fi
        if [[ "$hostname1" =~ ^[a-zA-Z0-9\u4e00-\u9fa5.-]+$ ]]; then
            break
        else
            echo "格式不正确，请重新输入!"
        fi
    done

    while true; do
        read -p "请输入一个或多个二级域名（不含一级域名，以空格分开）：" subdomains
        if [ -z "$subdomains" ]; then
            return
        fi
        valid=true
        for sub in $subdomains; do
            if ! [[ "$sub" =~ ^[a-zA-Z0-9\u4e00-\u9fa5.-]+$ ]]; then
                valid=false
                break
            fi
        done
        
        if $valid; then
            hostname2=$(echo "$subdomains" | tr ' ' ',')
            break
        else
            echo "格式不正确，请重新输入!"
        fi
    done

    while true; do
        read -p "请输入IPv4解析数量（可设置为0，留空则返回上级）：" ipv4_count
        if [[ -z "$ipv4_count" ]]; then
            return
        elif [[ "$ipv4_count" =~ ^[0-9]+$ ]]; then
            break
        else
            echo "格式不正确，请重新输入!"
        fi
    done
    
    while true; do
        read -p "请输入IPv6解析数量（可设置为0，留空则返回上级）：" ipv6_count
        if [[ -z "$ipv6_count" ]]; then
            return
        elif [[ "$ipv6_count" =~ ^[0-9]+$ ]]; then
            break
        else
            echo "格式不正确，请重新输入!"
        fi
    done

    look_cfst_rules

    while true; do
        read -p "请输入CloudflareST命令（无需以“./CloudflareST”开头，留空则返回上级）：" cf_command
        if [ -z "$cf_command" ]; then
            return
        else
            break
        fi
    done
    cf_command=$(echo "$cf_command" | tr ' ' ',')
    
     while true; do
        read -p "从URL链接获取IPv4地址：" v4_url
        if [ -n "$v4_url" ] && ! [[ "$v4_url" =~ ^https?://.* ]]; then
            echo "无效的IPv4 URL，请重新输入！"
        else
            break
        fi
    done

    while true; do
        read -p "从URL链接获取IPv6地址：" v6_url
        if [ -n "$v6_url" ] && ! [[ "$v6_url" =~ ^https?://.* ]]; then
            echo "无效的IPv6 URL，请重新输入！"
        else
            break
        fi
    done

    while true; do
    read -p "请选择推送方式 (0-不设置, 1-Telegram, 2-PushPlus, 3-Server酱, 4-PushDeer, 5-企业微信, 6-Synology Chat，以空格分开)： " push_mod

    # 将输入的推送方式按空格分隔并删除多余空格
    push_mod=$(echo "$push_mod" | tr -s ' ')

    # 验证输入是否仅包含0~6之间的数字，并且按空格分隔
    if [[ ! "$push_mod" =~ ^([0-6])([[:space:]][0-6])*$ ]]; then
        echo "无效输入，请输入 0 或 1~6 的数字"
        continue
    fi

    # 判断是否同时包含 0 和其他数字
    if [[ "$push_mod" =~ (^0[[:space:]]|[[:space:]]0[[:space:]]|0$) && "$push_mod" != "0" ]]; then
        echo "无效输入：0 只能单独存在，不能与其他数字一起使用"
        continue
    fi

    # 检查是否有重复项
    if [[ $(echo "$push_mod" | tr ' ' '\n' | sort | uniq -d | wc -l) -gt 0 ]]; then
        echo "无效输入：数字不能重复"
        continue
    fi

    # 将空格替换为逗号
    push_mod=$(echo "$push_mod" | tr ' ' ',')
    break
done

#add_blank_line

# 写入解析信息到配置文件
echo "# Resolve section" >> "$config_file"
echo "add_ddns=($add_ddns),ddns_name=($ddns_name),hostname1=($hostname1),hostname2=($hostname2),v4_num=($ipv4_count),v6_num=($ipv6_count),cf_command=($cf_command),v4_url=($v4_url),v6_url=($v6_url),push_mod=($push_mod)" >> "$config_file"

echo "解析条目添加成功！"
sleep 1
push_settings  # 直接进入推送设置
}

# 删除解析
delete_resolve() {
    clear
    echo "================================="
    echo "           删除解析"
    echo "================================="
    
    look_ddns_simple

    echo "================================="
    
    read -p "请输入要删除的解析组名称（留空则返回上级）：" delete_ddns
    if [ -z "$delete_ddns" ]; then
        return
    fi

    # 检查解析组名称是否存在
    if ! grep -q "ddns_name=($delete_ddns)" "$config_file"; then
        echo "不存在该解析组名称！"
        sleep 1
        return
    fi

    # 确认删除
    read -p "确认删除解析组 $delete_ddns 吗？(y/n): " confirm_delete
    if [ "$confirm_delete" != "y" ]; then
        echo "取消删除操作。"
        sleep 1
        return
    fi

    # 删除匹配的解析组及其前面的空行
    sed -i "/^# Resolve section/{N; /ddns_name=($delete_ddns)/{d;}}" "$config_file"

    echo "解析组 $delete_ddns 已成功删除！"
    sleep 1
    resolve_settings
}

# 修改解析
modify_resolve() {
    clear
    echo "================================="
    echo "           修改解析"
    echo "================================="
    
    look_ddns_simple

    echo "================================="
    
    modify_resolve_field() {
    local field="$1"
    local new_value="$2"
    local config_file="$3"
    local ddns_name="$4"

    # 使用 | 作为分隔符避免URL中的 / 冲突，并匹配括号内的值
    sed -i -e "/ddns_name=($ddns_name)/{
        s|\($field=(\)[^)]*|\1$new_value|
    }" "$config_file"
}
    
    read -p "请输入要修改的解析组名称（留空则返回上级）：" modify_ddns
    if [ -z "$modify_ddns" ]; then
        return
    fi

    # 检查解析组名称是否存在
    if ! grep -q "ddns_name=($modify_ddns)" "$config_file"; then
        echo "解析组不存在，请重新输入。"
        sleep 1
        modify_resolve
        return
    fi

    # 提示用户选择要修改的内容
    while true; do
        echo "请选择要修改的内容："
        echo "1. 一级域名"
        echo "2. 二级域名"
        echo "3. IPv4解析数量"
        echo "4. IPv6解析数量"
        echo "5. CloudflareST命令"
        echo "6. IPv4地址URL"
        echo "7. IPv6地址URL"
        echo "8. 推送渠道"
        echo "9. 返回"
        read -p "请输入选项 (1-9): " choice

        case $choice in
            1)
                read -p "请输入新的一级域名：" new_hostname1
                if [[ -n "$new_hostname1" && "$new_hostname1" =~ ^[a-zA-Z0-9\u4e00-\u9fa5.-]+$ ]]; then
                    modify_resolve_field "hostname1" "$new_hostname1" "$config_file" "$modify_ddns"
                    echo "一级域名已更新"
                else
                    echo "格式不正确，请重新输入"
                fi ;;
            2)
                read -p "请输入新的二级域名（以空格分开）：" new_hostname2
                new_hostname2=$(echo "$new_hostname2" | tr ' ' ',')
                modify_resolve_field "hostname2" "$new_hostname2" "$config_file" "$modify_ddns"
                echo "二级域名已更新" ;;
            3)
                read -p "请输入新的IPv4解析数量：" new_ipv4_count
                if [[ "$new_ipv4_count" =~ ^[0-9]+$ ]]; then
                    modify_resolve_field "v4_num" "$new_ipv4_count" "$config_file" "$modify_ddns"
                    echo "IPv4解析数量已更新"
                else
                    echo "格式不正确，请重新输入"
                fi ;;
            4)
                read -p "请输入新的IPv6解析数量：" new_ipv6_count
                if [[ "$new_ipv6_count" =~ ^[0-9]+$ ]]; then
                    modify_resolve_field "v6_num" "$new_ipv6_count" "$config_file" "$modify_ddns"
                    echo "IPv6解析数量已更新"
                else
                    echo "格式不正确，请重新输入"
                fi ;;
            5)
                look_cfst_rules
                read -p "请输入新的CloudflareST命令：" new_cf_command
                new_cf_command=$(echo "$new_cf_command" | tr ' ' ',')
                modify_resolve_field "cf_command" "$new_cf_command" "$config_file" "$modify_ddns"
                echo "CloudflareST命令已更新" ;;
            6)
                read -p "请输入新的IPv4地址URL：" new_v4_url
                if [[ -n "$new_v4_url" && "$new_v4_url" =~ ^https?://.* ]]; then
                    modify_resolve_field "v4_url" "$new_v4_url" "$config_file" "$modify_ddns"
                    echo "IPv4地址URL已更新"
                else
                    echo "URL格式不正确，请重新输入"
                fi ;;
            7)
                read -p "请输入新的IPv6地址URL：" new_v6_url
                if [[ -n "$new_v6_url" && "$new_v6_url" =~ ^https?://.* ]]; then
                    modify_resolve_field "v6_url" "$new_v6_url" "$config_file" "$modify_ddns"
                    echo "IPv6地址URL已更新"
                else
                    echo "URL格式不正确，请重新输入"
                fi ;;
            8)
                while true; do
                    read -p "请输入新的推送方式（0-不设置, 1-Telegram, 2-PushPlus, 3-Server酱, 4-PushDeer, 5-企业微信, 6-Synology Chat，以空格分隔）： " new_push_mod

                    # 去掉多余的空格
                    new_push_mod=$(echo "$new_push_mod" | tr -s ' ')

                    # 检查输入是否仅包含0-6之间的数字，并且按空格分隔
                    if [[ ! "$new_push_mod" =~ ^([0-6])([[:space:]][0-6])*$ ]]; then
                        echo "无效输入，请输入 0 或 1-6 的数字"
                        continue
                    fi

                    # 检查是否同时包含0和其他数字
                    if [[ "$new_push_mod" =~ (^0[[:space:]]|[[:space:]]0[[:space:]]|0$) && "$new_push_mod" != "0" ]]; then
                        echo "无效输入：0 只能单独存在，不能与其他数字一起使用"
                        continue
                    fi

                    # 检查是否有重复数字
                    if [[ $(echo "$new_push_mod" | tr ' ' '\n' | sort | uniq -d | wc -l) -gt 0 ]]; then
                        echo "无效输入：数字不能重复"
                        continue
                    fi

                    # 将空格替换为逗号
                    formatted_push_mod=$(echo "$new_push_mod" | tr ' ' ',')

                    # 更新推送方式
                    modify_resolve_field "push_mod" "$formatted_push_mod" "$config_file" "$modify_ddns"
                    echo "推送方式已更新"
                    break
                done
                ;;
            9)
                break
                ;;
            *)
                :
                ;;
        esac
    done

    echo "解析信息修改完毕。"
    sleep 1
    clear_input_buffer
    resolve_settings
}

# 启动解析
start() {
    local ddns_name=$1

    # 检查 ddns_name 是否存在，并从 Resolve Section 查找
    local resolve_line=$(grep -E "^add_ddns=\([^)]*\),ddns_name=\($ddns_name\)" "$config_file")

    if [ -z "$resolve_line" ]; then
        echo "未找到指定的解析组，请检查输入。"
        return 1
    fi

    # 提取 add_ddns 和相关解析信息
    local add_ddns=$(echo "$resolve_line" | sed -n 's/.*add_ddns=(\([^)]*\)).*/\1/p')
    local hostname1=$(echo "$resolve_line" | sed -n 's/.*hostname1=(\([^)]*\)).*/\1/p')
    local hostname2=$(echo "$resolve_line" | sed -n 's/.*hostname2=(\([^)]*\)).*/\1/p' | tr ',' ' ')  # 替换逗号为空格
    local v4_num=$(echo "$resolve_line" | sed -n 's/.*v4_num=(\([^)]*\)).*/\1/p')
    local v6_num=$(echo "$resolve_line" | sed -n 's/.*v6_num=(\([^)]*\)).*/\1/p')
    local cf_command=$(echo "$resolve_line" | sed -n 's/.*cf_command=(\([^)]*\)).*/\1/p' | tr ',' ' ')  # 替换逗号为空格
    local v4_url=$(echo "$resolve_line" | sed -n 's/.*v4_url=(\([^)]*\)).*/\1/p')
    local v6_url=$(echo "$resolve_line" | sed -n 's/.*v6_url=(\([^)]*\)).*/\1/p')
    local push_mod=$(echo "$resolve_line" | sed -n 's/.*push_mod=(\([^)]*\)).*/\1/p' | tr ',' ' ')  # 替换逗号为空格
    local clien=$(sed -n 's/.*clien=(\([0-7]\)).*/\1/p' "$config_file")

    # 使用 add_ddns 查找对应的 account_group
    local account_group_line=$(grep "^account_group=(\($add_ddns\))," "$config_file")
    if [ -z "$account_group_line" ]; then
        echo "未找到对应的账户组，请检查配置。"
        return 1
    fi

    # 提取从账户组获取的信息
    local x_email=$(echo "$account_group_line" | sed -n 's/.*x_email=(\([^)]*\)).*/\1/p')
    local zone_id=$(echo "$account_group_line" | sed -n 's/.*zone_id=(\([^)]*\)).*/\1/p')
    local api_key=$(echo "$account_group_line" | sed -n 's/.*api_key=(\([^)]*\)).*/\1/p')

    # 确保所有必要信息都已提取
    if [ -z "$x_email" ] || [ -z "$zone_id" ] || [ -z "$api_key" ] || \
       [ -z "$hostname1" ] || [ -z "$hostname2" ] || [ -z "$v4_num" ] || \
       [ -z "$v6_num" ] || [ -z "$cf_command" ] || [ -z "$v4_url" ] || \
       [ -z "$v6_url" ] || [ -z "$push_mod" ]; then
        echo "某些必要信息缺失，请检查配置。"
        return 1
    fi

    # 运行 start_ddns.sh 并传递所有参数
    source ./start_ddns.sh "$x_email" "$zone_id" "$api_key" "$hostname1" "$hostname2" "$v4_num" "$v6_num" "$cf_command" "$v4_url" "$v6_url" "$push_mod" "$clien"
}

# 执行解析
execute_resolve() {
    clear
    echo "================================="
    echo "           执行解析"
    echo "================================="

    look_ddns  # 查看现有解析组

    echo "================================="
    read -p "请输入要执行的解析组名称（留空则返回上级）：" selected_ddns
    if [ -z "$selected_ddns" ]; then
        return
    fi

    # 调用 start 函数获取相关信息并执行
    start "$selected_ddns"
}

# 查看计划任务
view_schedule() {
    clear
    echo "================================="
    echo "           查看计划任务"
    echo "================================="

    look_ddns  # 查看现有解析组

    echo "================================="
    # 提示用户输入解析组名称
    read -p "请输入要查看计划任务的解析组名称（留空则返回上级）：" selected_ddns
    if [ -z "$selected_ddns" ]; then
        return
    fi

    # 验证解析组是否存在
    if ! grep -q "ddns_name=($selected_ddns)" "$config_file"; then
        echo "解析组不存在，请重新输入。"
        sleep 1
        view_schedule
        return
    fi

    # 获取当前脚本路径
    script_dir="$(cd "$(dirname "$0")" && pwd)"

    # 显示计划任务成品
    echo "================================="
    echo "计划任务示例："
    echo "示例1：每4小时更新一次: 0 */4 * * * cd $script_dir && bash cf.sh start $selected_ddns"
    echo "示例2：每天5点更新一次: 0 5 * * * cd $script_dir && bash cf.sh start $selected_ddns"
    echo "================================="
    echo "请选择操作："
    echo "1. 创建计划任务示例1"
    echo "2. 创建计划任务示例2"
    echo "3. 返回上级"
    echo "================================="
    read -p "请选择操作 (1-3): " action_choice

    # 读取现有的计划任务
    existing_crontab=$(crontab -l 2>/dev/null)

    case $action_choice in
        1) 
            new_task="0 */4 * * * cd $script_dir && bash cf.sh start $selected_ddns"
            (echo "$existing_crontab"; echo "$new_task") | crontab -
            echo "计划任务示例1已创建！" ;;
           
        2) 
            new_task="0 5 * * * cd $script_dir && bash cf.sh start $selected_ddns"
            (echo "$existing_crontab"; echo "$new_task") | crontab -
            echo "计划任务示例2已创建！" ;;
            
        3) 
            clear_input_buffer; main_menu ;;
        *) 
            continue ;;
            
    esac

    echo "================================="
    read -p "按任意键返回上级菜单..." -n1 -s
}

# 推送设置菜单
push_settings() {
    while true; do
        clear
        echo "================================="
        echo "             推送管理"
        echo "================================="
        echo "1) Telegram"
        echo "2) PushPlus"
        echo "3) Server 酱"
        echo "4) PushDeer"
        echo "5) 企业微信"
        echo "6) Synology Chat"
        echo "7) 返回主菜单"
        echo "================================="
        read -p "请选择推送类型 (1-7): " push_type

        case $push_type in
            1) manage_push "Telegram" "telegram_bot_token" "telegram_user_id" "" "" "1" ;;
            2) manage_push "PushPlus" "pushplus_token" "" "" "" "2" ;;
            3) manage_push "Server 酱" "server_sendkey" "" "" "" "3" ;;
            4) manage_push "PushDeer" "pushdeer_pushkey" "" "" "" "4" ;;
            5) manage_push "企业微信" "wechat_corpid" "wechat_secret" "wechat_agentid" "wechat_userid" "5" ;;
            6) manage_push "Synology Chat" "synology_chat_url" "" "" "" "6" ;;
            7) clear_input_buffer; main_menu ;;
            *) : ;;
        esac
    done
}

# 通用函数：管理推送（设置、修改、删除）
manage_push() {
    local push_name="$1"
    local token_name="$2"
    local app_id_name="$3"
    local app_id2_name="$4"
    local app_id3_name="$5"
    local push_id="$6"  # 推送名称对应的数字

    while true; do
        clear
        echo "================================="
        echo "       $push_name 推送管理"
        echo "================================="
        echo "1. 设置参数"
        echo "2. 修改参数"
        echo "3. 删除推送"
        echo "4. 返回上级"
        echo "================================="
        read -p "请选择操作 (1-4): " push_choice

        case $push_choice in
            1)  # 设置参数
                if grep -q "push_name=($push_id)" "$config_file"; then
                    echo "$push_name 已经设置。"
                    sleep 1  # 自动返回上一级
                else
                    configure_push "set" "$push_name" "$token_name" "$app_id_name" "$app_id2_name" "$app_id3_name" "$push_id"
                fi
                ;;
            2)  # 修改参数
                if ! grep -q "push_name=($push_id)" "$config_file"; then
                    echo "$push_name 未设置，无法修改。"
                    sleep 1  # 自动返回上一级
                else
                    configure_push "modify" "$push_name" "$token_name" "$app_id_name" "$app_id2_name" "$app_id3_name" "$push_id"
                fi
                ;;
            3)  # 删除推送
                if grep -q "push_name=($push_id)" "$config_file"; then
                    delete_push_section "$push_name" "$push_id"
                else
                    echo "$push_name 未设置。"
                fi
                sleep 1  # 自动返回上一级
                ;;
            4)  # 返回上级
                return
                ;;
            *)
                :
                ;;
        esac
    done
}

# 通用函数：设置或修改推送参数
configure_push() {
    local mode="$1"  # 模式: set 或 modify
    local name="$2"
    local token_name="$3"
    local app_id_name="$4"
    local app_id2_name="$5"
    local app_id3_name="$6"
    local push_id="$7"

    if [ "$mode" == "set" ]; then
        echo "正在设置 $name 推送..."
    elif [ "$mode" == "modify" ]; then
        local current_values=$(grep "push_name=($push_id)" "$config_file" | sed "s/push_name=($push_id),//")
        echo "当前 $name 设置："
        echo "$current_values"
    fi

    # 读取用户输入的新参数值，确保输入不为空
    while true; do
        read -p "请输入 $token_name：" token_value
        if [ -z "$token_value" ]; then
            echo "$token_name 不能为空，请重新输入。"
        else
            break
        fi
    done

    if [ -n "$app_id_name" ]; then
        while true; do
            read -p "请输入 $app_id_name：" app_id_value
            if [ -z "$app_id_value" ]; then
                echo "$app_id_name 不能为空，请重新输入。"
            else
                break
            fi
        done
    fi

    if [ -n "$app_id2_name" ]; then
        while true; do
            read -p "请输入 $app_id2_name：" app_id2_value
            if [ -z "$app_id2_value" ]; then
                echo "$app_id2_name 不能为空，请重新输入。"
            else
                break
            fi
        done
    fi

    if [ -n "$app_id3_name" ]; then
        while true; do
            read -p "请输入 $app_id3_name：" app_id3_value
            if [ -z "$app_id3_value" ]; then
                echo "$app_id3_name 不能为空，请重新输入。"
            else
                break
            fi
        done
    fi

    # 验证输入不为空后进行操作
    if [ "$mode" == "set" ]; then
        # 新增推送设置到配置文件（只添加非空的参数）
        echo "# Push section" >> "$config_file"
        echo -n "push_name=($push_id)," >> "$config_file"
        echo -n "$token_name=($token_value)" >> "$config_file"
        [ -n "$app_id_name" ] && echo -n ",$app_id_name=($app_id_value)" >> "$config_file"
        [ -n "$app_id2_name" ] && echo -n ",$app_id2_name=($app_id2_value)" >> "$config_file"
        [ -n "$app_id3_name" ] && echo -n ",$app_id3_name=($app_id3_value)" >> "$config_file"
        echo "" >> "$config_file"  # 换行
        echo "$name 参数已设置完成！"
    elif [ "$mode" == "modify" ]; then
        # 使用sed准确修改配置文件中的值，只有非空值被修改
        sed -i -e "/push_name=($push_id)/{
            s|\($token_name=(\)[^)]*|\1$token_value|;
            $( [ -n "$app_id_name" ] && echo "s|\($app_id_name=(\)[^)]*|\1$app_id_value|;" )
            $( [ -n "$app_id2_name" ] && echo "s|\($app_id2_name=(\)[^)]*|\1$app_id2_value|;" )
            $( [ -n "$app_id3_name" ] && echo "s|\($app_id3_name=(\)[^)]*|\1$app_id3_value|;" )
        }" "$config_file"
        echo "$name 参数已更新！"
    fi

    sleep 1  # 自动返回上一级
}

# 删除推送设置
delete_push_section() {
    local push_name="$1"
    local push_id="$2"

    # 提示用户确认删除操作
    read -p "确认删除 $push_name 的推送设置吗？(y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        echo "取消删除操作。"
        return
    fi

    # 使用sed精确删除对应push_id的配置段，确保只删除该推送的配置
    sed -i "/^# Push section/{N; /push_name=($push_id)/{d;}}" "$config_file"

    echo "$push_name 的推送设置已删除。"
}

# 插件设置
write_plugin_settings() {
    local config_file="$config_file"
    local current_clien=0
    local plugin_section_found=false

    # 定义插件数组
    plugins=("不使用" "passwall" "passwall2" "shadowsocksr" "openclash" "shellcrash" "nekoclash" "bypass")

    # 用于更新clien的函数，确保只修改现有的clien行
    update_clien() {
        local new_value="$1"
        local config_file="$2"

        # 如果存在clien行，更新它；否则添加新的clien行
        if grep -q "clien=" "$config_file"; then
            sed -i -e "s/clien=([0-7])/clien=($new_value)/" "$config_file"
        else
            echo "clien=($new_value)" >> "$config_file"
        fi
    }

    # 函数用于显示插件设置页面
    display_plugin_menu() {
        clear
        echo "================================="
        echo "           插件设置"
        echo "================================="
        
        # 检查是否存在 # Plugin section 和 clien=() 行
        if grep -q "# Plugin section" "$config_file" && grep -q "clien=" "$config_file"; then
            # 提取当前的插件设置数字
            current_clien=$(grep "clien=" "$config_file" | sed 's/[^0-9]//g')
            plugin_section_found=true
        else
            # 如果没有找到 Plugin section 和 clien 行，创建它们
            echo "# Plugin section" >> "$config_file"
            echo "clien=(0)" >> "$config_file"
            current_clien=0
        fi

        # 显示当前插件
        echo "当前插件：${plugins[$current_clien]}"

        # 显示插件选项
        echo "请选择插件："
        echo "0. 不使用"
        echo "1. passwall"
        echo "2. passwall2"
        echo "3. shadowsocksr"
        echo "4. openclash"
        echo "5. shellcrash"
        echo "6. nekoclash"
        echo "7. bypass"
        echo "8. 返回主菜单"
    }

    while true; do
        # 显示插件设置页面
        display_plugin_menu

        # 获取用户输入
        read -p "请输入对应的数字 (0-8): " choice

        # 处理用户选择
        if [[ "$choice" == "8" ]]; then
            clear_input_buffer    # 清除输入缓冲区
            main_menu             # 返回主菜单
            return 0
        elif [[ "$choice" =~ ^[0-7]$ ]]; then
            # 使用 update_clien 函数更新 clien 设置
            update_clien "$choice" "$config_file"
            echo "插件已设置为: ${plugins[$choice]}"
        else
            echo "无效输入，请输入0-8之间的数字。"
        fi

        # 刷新显示插件设置页面
        echo "================================="
    done
}

# 主程序入口
main_menu
