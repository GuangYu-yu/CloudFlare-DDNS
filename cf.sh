#!/bin/bash

# 全局变量：用于存储网络状态
ipv6_status=""
ipv4_status=""

# 检测cf.yaml文件
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
    urls=("ip.sb")

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

# 读取并丢弃所有在缓冲区中的输入
clear_input_buffer() {
    cat /dev/null > /dev/tty
}

# 输出已存在的账户信息
look_account_group() {
    sed -n 's/account_group=(\([^)]*\)), x_email=(\([^)]*\)), zone_id=(\([^)]*\)), api_key=(\([^)]*\))/账户组：\1 邮箱：\2 区域ID：\3 API Key：\4/p' "$config_file"
}

# 查看解析
look_ddns() {
    sed -n '/add_ddns=(\([^)]*\)), ddns_name=(\([^)]*\)), hostname1=(\([^)]*\)), hostname2=(\([^)]*\)), v4_num=(\([^)]*\)), v6_num=(\([^)]*\)), cf_command=(\([^)]*\)), v4_url=(\([^)]*\)), v6_url=(\([^)]*\))/ {
        s/add_ddns=(\([^)]*\)), ddns_name=(\([^)]*\)), hostname1=(\([^)]*\)), hostname2=(\([^)]*\)), v4_num=(\([^)]*\)), v6_num=(\([^)]*\)), cf_command=(\([^)]*\)), v4_url=(\([^)]*\)), v6_url=(\([^)]*\))/账户组：\1\n解析组：\2\n一级域名：\3\n二级域名：\4\nIPv4数量：\5\nIPv6数量：\6\nCloudflareST命令：\7\nIPv4地址URL：\8\nIPv6地址URL：\9\n\n/
        p
    }' "$config_file"
}


look_cfst_rules() {
    echo "    示例：-n 500 -tll 40 -tl 280 -dn 5 -sl 15 -p 5"
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

main_menu() {
    local timeout_sec=60  # 设置超时时间，单位为秒

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
        echo "7. 退出"
        echo "================================="
        
        clear_input_buffer
        
        # 使用timeout命令设置超时时间
        read -t $timeout_sec -p "请选择 (1-6): " choice

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
            7) exit 0 ;;
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
            4) clear_input_buffer 
               main_menu;;
            *) continue ;;
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
        read -p "请输入自定义账户组名称（只能包含字母、数字和下划线）：" account_group

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

    # 写入账户相关信息到配置文件，并使用标识分隔账户部分
    echo "# Account section" >> "$config_file"
    echo "account_group=($account_group), x_email=($x_email), zone_id=($zone_id), api_key=($api_key)" >> "$config_file"

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

    # 从配置文件中删除匹配的账户组整行
    sed -i "/account_group=($delete_group),/d" "$config_file"

    echo "账户组 $delete_group 已成功删除！"
    sleep 1
    
    clear_input_buffer
    
    account_settings
}

# 修改账户
modify_account() {
    
    clear_input_buffer
    
    clear
    echo "================================="
    echo "           修改账户"
    echo "================================="
    echo "已设置的账户信息："

    look_account_group

    echo "================================="
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
        echo "4. 返回"
        read -p "请输入选项 (1-4)：" choice

        case $choice in
            1)  
                read -p "请输入新的账户登陆邮箱：" new_email
                # 验证邮箱格式
                if [[ -n "$new_email" && "$new_email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
                    # 使用 sed 精确更新邮箱字段，保留其他字段
                    sed -i "s/\(account_group=($modify_account_group), x_email=\)[^,]*,/\1($new_email),/" "$config_file"
                    echo "邮箱已更新"
                else
                    echo "邮箱格式不正确，请重新输入"
                fi ;;
                
            2)  
                read -p "请输入新的区域ID：" new_zone_id
                if [[ -n "$new_zone_id" ]]; then
                    # 使用 sed 精确更新区域ID字段，保留其他字段
                    sed -i "s/\(account_group=($modify_account_group), \(.*\), zone_id=\)[^,]*,/\1($new_zone_id),/" "$config_file"
                    echo "区域ID已更新"
                else
                    echo "输入不能为空，请重新输入"
                fi ;;
                
            3)  
                read -p "请输入新的API Key：" new_api_key
                if [[ -n "$new_api_key" ]]; then
                    # 使用 sed 精确更新 API Key 字段，保留其他字段
                    sed -i "s/\(account_group=($modify_account_group), \(.*\), api_key=(\)[^)]*/\1$new_api_key/" "$config_file"
                    echo "API Key已更新"
                else
                    echo "输入不能为空，请重新输入"
                fi ;;
                
            4)  
                break ;;
                
            *)  
                continue ;;
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
        
        look_account_group

        echo "================================="
        
        echo "1. 查看解析"
        echo "2. 添加解析"
        echo "3. 删除解析"
        echo "4. 修改解析"
        echo "5. 返回主菜单"
        echo "================================="
        
        read -p "请选择 (1-4): " choice

        case $choice in
            1) view_resolve ;;
            2) add_resolve ;;
            3) delete_resolve ;;
            4) modify_resolve ;;
            5) clear_input_buffer; main_menu ;;
            *) continue ;;
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
    
    look_account_group

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

    # 写入解析相关信息到配置文件，并使用标识分隔解析部分
    echo "# Resolve section" >> "$config_file"
    echo "add_ddns=($add_ddns), ddns_name=($ddns_name), hostname1=($hostname1), hostname2=($hostname2), v4_num=($ipv4_count), v6_num=($ipv6_count), cf_command=($cf_command), v4_url=($v4_url), v6_url=($v6_url)" >> "$config_file"

    echo "解析条目添加成功！"
    sleep 1
    resolve_settings
}


# 删除解析
delete_resolve() {
    clear
    echo "================================="
    echo "           删除解析"
    echo "================================="
    
    look_account_group

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

    # 从配置文件中删除匹配的解析组整行
    sed -i "/ddns_name=($delete_ddns),/d" "$config_file"

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
    
    look_ddns  # 显示现有解析

    echo "================================="
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
        echo "8. 返回"
        read -p "请输入选项 (1-8): " choice

        case $choice in
            1)
                read -p "请输入新的一级域名：" new_hostname1
                if [[ -n "$new_hostname1" && "$new_hostname1" =~ ^[a-zA-Z0-9\u4e00-\u9fa5.-]+$ ]]; then
                    sed -i "s/\(ddns_name=($modify_ddns), hostname1=\)[^,]*,/\1($new_hostname1),/" "$config_file"
                    echo "一级域名已更新"
                else
                    echo "格式不正确，请重新输入"
                fi ;;
            2)
                read -p "请输入新的二级域名（以空格分开）：" new_hostname2
                new_hostname2=$(echo "$new_hostname2" | tr ' ' ',')
                sed -i "s/\(ddns_name=($modify_ddns), \(.*\), hostname2=\)[^,]*,/\1($new_hostname2),/" "$config_file"
                echo "二级域名已更新" ;;
            3)
                read -p "请输入新的IPv4解析数量：" new_ipv4_count
                if [[ "$new_ipv4_count" =~ ^[0-9]+$ ]]; then
                    sed -i "s/\(ddns_name=($modify_ddns), \(.*\), v4_num=\)[^,]*,/\1($new_ipv4_count),/" "$config_file"
                    echo "IPv4解析数量已更新"
                else
                    echo "格式不正确，请重新输入"
                fi ;;
            4)
                read -p "请输入新的IPv6解析数量：" new_ipv6_count
                if [[ "$new_ipv6_count" =~ ^[0-9]+$ ]]; then
                    sed -i "s/\(ddns_name=($modify_ddns), \(.*\), v6_num=\)[^,]*,/\1($new_ipv6_count),/" "$config_file"
                    echo "IPv6解析数量已更新"
                else
                    echo "格式不正确，请重新输入"
                fi ;;
            5)
                read -p "请输入新的CloudflareST命令：" new_cf_command
                new_cf_command=$(echo "$new_cf_command" | tr ' ' ',')
                sed -i "s/\(ddns_name=($modify_ddns), \(.*\), cf_command=\)[^,]*,/\1($new_cf_command),/" "$config_file"
                echo "CloudflareST命令已更新" ;;
            6)
                read -p "请输入新的IPv4地址URL：" new_v4_url
                if [[ -n "$new_v4_url" && "$new_v4_url" =~ ^https?://.* ]]; then
                    sed -i "s|\(ddns_name=($modify_ddns), \(.*\), v4_url=\)[^,]*,|\1($new_v4_url),|" "$config_file"
                    echo "IPv4地址URL已更新"
                else
                    echo "URL格式不正确，请重新输入"
                fi ;;
            7)
                read -p "请输入新的IPv6地址URL：" new_v6_url
                if [[ -n "$new_v6_url" && "$new_v6_url" =~ ^https?://.* ]]; then
                    sed -i "s|\(ddns_name=($modify_ddns), \(.*\), v6_url=(\)[^)]*|\1($new_v6_url|g" "$config_file"
                    echo "IPv6地址URL已更新"
                else
                    echo "URL格式不正确，请重新输入"
                fi ;;
            8)
                break ;;
            *)
                continue ;;
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
    local resolve_line=$(grep -E "^add_ddns=\(.*\), ddns_name=\($ddns_name\)" "$config_file")

    if [ -z "$resolve_line" ]; then
        echo "未找到指定的解析组，请检查输入。"
        return 1
    fi

    # 提取 add_ddns 和相关解析信息
    local add_ddns=$(echo "$resolve_line" | sed -n 's/.*add_ddns=(\([^)]*\)).*/\1/p')
    local hostname1=$(echo "$resolve_line" | sed -n 's/.*hostname1=(\([^)]*\)).*/\1/p')
    local hostname2=$(echo "$resolve_line" | sed -n 's/.*hostname2=(\([^)]*\)).*/\1/p' | sed 's/,/ /g')  # 替换逗号为空格
    local v4_num=$(echo "$resolve_line" | sed -n 's/.*v4_num=(\([^)]*\)).*/\1/p')
    local v6_num=$(echo "$resolve_line" | sed -n 's/.*v6_num=(\([^)]*\)).*/\1/p')
    local cf_command=$(echo "$resolve_line" | sed -n 's/.*cf_command=(\([^)]*\)).*/\1/p' | sed 's/,/ /g')  # 替换逗号为空格
    local v4_url=$(echo "$resolve_line" | sed -n 's/.*v4_url=(\([^)]*\)).*/\1/p')
    local v6_url=$(echo "$resolve_line" | sed -n 's/.*v6_url=(\([^)]*\)).*/\1/p')
    
    # 使用 add_ddns 查找对应的 account_group
    local account_group_line=$(grep "^account_group=(\($add_ddns\))" "$config_file")
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
       [ -z "$v6_url" ]; then
        echo "某些必要信息缺失，请检查配置。"
        return 1
    fi

    # 运行 start_ddns.sh 并传递所有参数，使用 exec 来替换当前脚本进程
exec ./start_ddns.sh "$x_email" "$zone_id" "$api_key" "$hostname1" "$hostname2" "$v4_num" "$v6_num" "$cf_command" "$v4_url" "$v6_url"
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
            echo "计划任务示例1已创建！"
            ;;
        2) 
            new_task="0 5 * * * cd $script_dir && bash cf.sh start $selected_ddns"
            (echo "$existing_crontab"; echo "$new_task") | crontab -
            echo "计划任务示例2已创建！"
            ;;
        3) 
            echo "返回上级菜单。"
            return
            ;;
        *) 
            echo "无效选项，请重新选择。"
            ;;
    esac

    echo "================================="
    read -p "按任意键返回上级菜单..." -n1 -s
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
