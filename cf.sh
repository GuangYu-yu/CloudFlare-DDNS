#!/bin/bash

# 配置文件路径
config_file="config.cfg"
resolve_file="resolve_list.txt"

# 显示网络支持状态
detect_ip_addresses() {
    echo "检测外网IP支持情况..."
    ipv6_support=$(curl -s6 ifconfig.co || curl -s6 ipinfo.io || curl -s6 api64.ipify.org > /dev/null && echo "IPv6:√" || echo "IPv6:×")
    ipv4_support=$(curl -s4 ifconfig.co || curl -s4 ipinfo.io || curl -s4 api64.ipify.org > /dev/null && echo "IPv4:√" || echo "IPv4:×")

    echo "$ipv6_support"
    echo "$ipv4_support"
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo "================================="
        echo "           主菜单"
        echo "================================="
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
            3) push_settings ;;
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
        echo "================================="
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

# 推送设置
push_settings() {
    while true; do
        clear
        echo "================================="
        echo "         推送设置"
        echo "================================="
        echo "1. Telegram"
        echo "2. Pushplus"
        echo "================================="
        read -p "请选择推送渠道（留空则返回上级）: " choice

        case $choice in
            1) read -p "请输入Telegram Token（留空则返回上级）: " tg_token ;;
            2) read -p "请输入Pushplus Token（留空则返回上级）: " pp_token ;;
            "") return ;;
            *) echo "无效选项，请重新选择。" ;;
        esac
    done
}

# 添加账户
add_account() {
    local email=""
    local zone_id=""
    local api_key=""

    while true; do
        clear
        echo "================================="
        echo "           添加账户"
        echo "================================="
        echo "1. 设置账户登录邮箱 (当前: $email)"
        echo "2. 设置区域ID (当前: $zone_id)"
        echo "3. 设置API Key (当前: $api_key)"
        echo "================================="
        read -p "请选择功能（留空则返回上级）: " choice

        case $choice in
            1) read -p "请输入账户登录邮箱: " email ;;
            2) read -p "请输入区域ID: " zone_id ;;
            3) read -p "请输入API Key: " api_key ;;
            "") 
                if [[ -n "$email" && -n "$zone_id" && -n "$api_key" ]]; then
                    # 保存到配置文件
                    echo "email=$email" >> "$config_file"
                    echo "zone_id=$zone_id" >> "$config_file"
                    echo "api_key=$api_key" >> "$config_file"
                    echo "账户信息已保存。"
                else
                    echo "信息不完整，无法保存账户。"
                fi
                return ;;
            *) echo "无效选项，请重新选择。" ;;
        esac
    done
}

# 删除账户
remove_account() {
    echo "================================="
    echo "           删除账户"
    echo "================================="
    # 读取账户记录
    if [[ ! -f "$config_file" ]]; then
        echo "没有找到账户记录。"
        return
    fi

    cat "$config_file"

    read -p "请输入要删除的账户邮箱（留空则返回上级）: " email_to_remove

    if [[ -z "$email_to_remove" ]]; then
        echo "未选择账户，返回上级。"
        return
    fi

    # 删除账户
    grep -v "^email=$email_to_remove" "$config_file" > temp_file && mv temp_file "$config_file"
    echo "账户 '$email_to_remove' 已删除。"
}

# 修改账户
modify_account() {
    echo "================================="
    echo "           修改账户"
    echo "================================="
    # 读取账户记录
    if [[ ! -f "$config_file" ]]; then
        echo "没有找到账户记录。"
        return
    fi

    cat "$config_file"

    read -p "请输入要修改的账户邮箱（留空则返回上级）: " email_to_modify

    if [[ -z "$email_to_modify" ]]; then
        echo "未选择账户，返回上级。"
        return
    fi

    read -p "请输入新的账户登录邮箱（留空则保持不变）: " new_email
    read -p "请输入新的区域ID（留空则保持不变）: " new_zone_id
    read -p "请输入新的API Key（留空则保持不变）: " new_api_key

    # 修改账户信息
    if [[ -n "$new_email" ]]; then
        sed -i "s/^email=$email_to_modify/email=$new_email/" "$config_file"
    fi
    if [[ -n "$new_zone_id" ]]; then
        sed -i "s/^zone_id=.*$/zone_id=$new_zone_id/" "$config_file"
    fi
    if [[ -n "$new_api_key" ]]; then
        sed -i "s/^api_key=.*$/api_key=$new_api_key/" "$config_file"
    fi

    echo "账户 '$email_to_modify' 已修改。"
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
        echo "        延迟测速线程；越多延迟测速越快，性能弱的设备 (如路由器) 请勿太
        echo "    -p 2000"
        echo "        CDN节点测试数量；设置为0表示不测试，设置为1表示测试1个节点，默认为2000个节点。"
        echo "    -d 10"
        echo "        延迟测速时间，单位秒。"
        
        # 保存解析信息到文件
        echo "$primary_domain,$mode,$sub_domains,$sub_domain,$ipv4_count,$ipv6_count,$cf_command" >> "$resolve_file"
        echo "解析信息已保存。"

        read -p "是否需要设置计划任务？（y/n）: " set_cron
        if [[ $set_cron == "y" ]]; then
            setup_cron_jobs
        fi

        read -p "继续添加解析？（y/n）: " continue
        if [[ $continue != "y" ]]; then
            return
        fi
    done
}

# 删除解析
remove_resolve() {
    echo "================================="
    echo "           删除解析"
    echo "================================="
    # 读取解析记录
    if [[ ! -f "$resolve_file" ]]; then
        echo "没有找到账户记录。"
        return
    fi

    cat "$resolve_file"

    read -p "请输入要删除的解析条目编号（留空则返回上级）: " entry_to_remove

    if [[ -z "$entry_to_remove" ]]; then
        echo "未选择条目，返回上级。"
        return
    fi

    # 删除解析条目
    sed -i "${entry_to_remove}d" "$resolve_file"
    echo "解析条目编号 '$entry_to_remove' 已删除。"
}

# 修改解析
modify_resolve() {
    echo "================================="
    echo "           修改解析"
    echo "================================="
    # 读取解析记录
    if [[ ! -f "$resolve_file" ]]; then
        echo "没有找到账户记录。"
        return
    fi

    cat "$resolve_file"

    read -p "请输入要修改的解析条目编号（留空则返回上级）: " entry_to_modify

    if [[ -z "$entry_to_modify" ]]; then
        echo "未选择条目，返回上级。"
        return
    fi

    read -p "请输入新的一级域名（留空则保持不变）: " new_primary_domain
    read -p "请选择新的模式（留空则保持不变）: " new_mode
    read -p "请输入新的二级域名（留空则保持不变）: " new_sub_domain
    read -p "请分别输入新的IPv4和IPv6地址解析数量（以空格隔开，留空则保持不变）: " new_ipv4_count new_ipv6_count
    read -p "请输入新的CloudflareST命令（留空则保持不变）: " new_cf_command

    # 修改解析信息
    current_entry=$(sed -n "${entry_to_modify}p" "$resolve_file")
    IFS=',' read -r primary_domain mode sub_domains sub_domain ipv4_count ipv6_count cf_command <<< "$current_entry"

    if [[ -n "$new_primary_domain" ]]; then primary_domain="$new_primary_domain"; fi
    if [[ -n "$new_mode" ]]; then mode="$new_mode"; fi
    if [[ -n "$new_sub_domain" ]]; then sub_domain="$new_sub_domain"; fi
    if [[ -n "$new_ipv4_count" ]]; then ipv4_count="$new_ipv4_count"; fi
    if [[ -n "$new_ipv6_count" ]]; then ipv6_count="$new_ipv6_count"; fi
    if [[ -n "$new_cf_command" ]]; then cf_command="$new_cf_command"; fi

    echo "$primary_domain,$mode,$sub_domains,$sub_domain,$ipv4_count,$ipv6_count,$cf_command" | sed -i "${entry_to_modify}s/.*/$(cat -)/" "$resolve_file"
    echo "解析条目编号 '$entry_to_modify' 已修改。"
}

# 查看计划任务
view_cron_jobs() {
    clear
    echo "================================="
    echo "         查看计划任务"
    echo "================================="
    crontab -l | grep '/path/to/your/script.sh'
    read -p "按 Enter 返回主菜单..."
}

# 设置计划任务
setup_cron_jobs() {
    echo "================================="
    echo "       设置计划任务"
    echo "================================="
    while IFS=, read -r primary_domain mode sub_domains sub_domain ipv4_count ipv6_count cf_command; do
        # 每个解析条目对应一个计划任务
        entry_num=$(grep -n "$primary_domain" "$resolve_file" | cut -d: -f1)
        cron_job="0 4 * * * /path/to/your/script.sh resolve ${entry_num}"
        echo "设置计划任务：$cron_job"
        (crontab -l; echo "$cron_job") | crontab -
    done < "$resolve_file"
}

# 执行解析
execute_resolve() {
    while true; do
        clear
        echo "================================="
        echo "         执行解析"
        echo "================================="
        read -p "请选择解析条目编号（留空则返回上级）: " entry_num

        if [[ -z "$entry_num" ]]; then
            return
        fi

        entry=$(sed -n "${entry_num}p" "$resolve_file")
        if [[ -z "$entry" ]]; then
            echo "无效的条目编号。"
            return
        fi

        IFS=',' read -r primary_domain mode sub_domains sub_domain ipv4_count ipv6_count cf_command <<< "$entry"
        # 执行解析逻辑
        echo "执行 CloudflareST 命令：$cf_command"
        $cf_command

        # 示例推送结果
        echo "解析完成："
        echo "    一级域名: $primary_domain"
        echo "    模式: $mode"
        echo "    IPv4 数量: $ipv4_count"
        echo "    IPv6 数量: $ipv6_count"
        
        # 推送结果
        # 这里可以添加推送逻辑

        read -p "继续执行解析？（y/n）: " continue
        if [[ $continue != "y" ]]; then
            return
        fi
    done
}

# 启动主菜单
main_menu
