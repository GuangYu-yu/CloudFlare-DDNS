#!/bin/bash

# 函数：错误输出
print_error() {
    echo "错误: $1" >&2
}

# 函数：信息输出
print_info() {
    echo "$1"
}

# 传入变量
add_ddns=$1
ddns_name=$2
x_email=$3
zone_id=$4
api_key=$5
hostname1=$6
hostname2=$7
v4_num=$8
v6_num=$9
cf_command=${10}
v4_url=${11}
v6_url=${12}
push_mod=${13}
clien=${14:-0}
config_file="../${15}"

# 限制测速地址最大行数
max_ipv4_lines=1000000
max_ipv6_lines=1000000

# 登录重试设置
max_login_retries=10 # 最大重试次数
login_retry_delay=2 # 重试延迟时间
max_single_login_time=5 # 单次登录最大等待时间（秒）

# 处理Ipv4和Ipv6的URL重试参数
max_retries=5 # 最大重试次数
retry_delay=2 # 重试延迟时间
single_attempt_timeout=3  # 单次尝试的超时时间（秒）

# 定义 csvfile 变量
csvfile="result.csv"

# 只在非"未指定"模式下组合主机名
if [ "$add_ddns" != "未指定" ]; then
    hostnames=$(echo $hostname2 | tr ' ' '\n' | sed "s/$/.${hostname1}/" | tr '\n' ' ' | sed 's/ $//')
    if [ -z "$hostnames" ]; then
        print_error "主机名组合失败"
        exit 1
    fi

    # 将 hostnames 分割成数组
    IFS=' ' read -ra domains <<< "$hostnames"
    domain_count=${#domains[@]}
fi

GetProxName() {
    if [ "$clien" == "不使用" ]; then
        CLIEN=""
    else
        CLIEN="$clien"
    fi
}

# 函数：停止插件
stop_plugin() {
  if [ -z "$CLIEN" ]; then
    print_info "按配置不停止插件"
  else
    if ! /etc/init.d/$CLIEN stop; then
        print_error "停止 $CLIEN 失败"
    else
        print_info "停止 $CLIEN"
        plugin_status="stopped"
    fi
  fi
}

# 函数：重启插件
restart_plugin() {
    # 只在非"未指定"模式且有设置插件时执行
    if [ "$add_ddns" != "未指定" ] && [ -n "$CLIEN" ]; then
        if [ -z "$CLIEN" ]; then
            print_info "根据配置，插件不会重启"
            sleep 2
        else
            if ! /etc/init.d/$CLIEN restart; then
                print_error "重启 $CLIEN 失败"
            else
                print_info "已重启 $CLIEN"
                print_info "为了确保 Cloudflare API 连接正常，DNS 记录更新将在 10 秒后开始"
                plugin_status="running"
                sleep 10
            fi
        fi
    fi
}

# 函数：处理脚本退出时的操作
handle_err() {
  if [ -n "$CLIEN" ] && [ "$plugin_status" = "stopped" ]; then
    print_info "恢复后台进程"
    if ! /etc/init.d/$CLIEN start; then
        print_error "启动 $CLIEN 失败"
    fi
  fi
}

# 捕获脚本退出信号，调用handle_err函数
trap handle_err HUP INT TERM EXIT

# 获取CLIEN的值
GetProxName

# IPv4 地址的正则表达式，用于匹配合法的IPv4地址
ipv4Regex="((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])"

# 默认关闭 Cloudflare 的代理功能
proxy="false"

# 初始化存储 DNS 记录和排除 IP 地址的数组
chkDnsArr=()    # 存储 Cloudflare 上 DNS 记录的数组
delDnsArr=()    # 存储待删除 DNS 记录的数组
excludeIp=()    # 存储需要排除的 IP 地址数组

# 函数：检查 Cloudflare 上的 DNS 记录，并准备删除的记录列表
CheckDelCFDns() {
  local domain="$1"
  local record_type="$2"
  listDnsApi="https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?type=${record_type}&name=${domain}"
  excludeIp=()     # 清空排除 IP 地址数组
  delDnsArr=()     # 清空待删除 DNS 记录数组
  chkDnsArr=()     # 清空存储 DNS 记录的数组
  
  # 使用 curl 发送 GET 请求获取当前 DNS 记录
  res=$(curl -s -X GET "$listDnsApi" -H "X-Auth-Email:$x_email" -H "X-Auth-Key:$api_key" -H "Content-Type:application/json")
  total_ct=$(echo "$res" | jq -r ".result_info.total_count")  # 获取 DNS 记录的总数

  for ((i = 0; i < total_ct; i++)); do
    # 提取每条记录的 ID 和 IP 地址
    record_id=$(echo "$res" | jq -r ".result[$i].id")
    ip=$(echo "$res" | jq -r ".result[$i].content")
    chkDnsArr+=("$record_id"":""$ip")  # 将记录 ID 和 IP 地址添加到 chkDnsArr 数组中
  done
}

# 函数：检查 DNS 记录是否在排除 IP 地址列表中
findRecInExcludeArr() {
  local rec=$1
  local sparr=()
  IFS=':' read -ra sparr <<<"$rec"  # 将记录分割成 ID 和 IP 地址
  for ip in "${excludeIp[@]}"; do
    if [ "${sparr[1]}" == "$ip" ]; then
      return 0  # 如果 IP 地址在排除列表中，则返回 0
    fi
  done

  return 1  # 如果 IP 地址不在排除列表中，则返回 1
}

# 函数：过滤待删除的 DNS 记录
FilterRec() {
  delDnsArr=()  # 清空待删除 DNS 记录数组
  for i in "${!chkDnsArr[@]}"; do
    findRecInExcludeArr "${chkDnsArr[$i]}"  # 检查记录是否在排除列表中
    if [ $? -eq 1 ]; then
      local sparr=()
      IFS=':' read -ra sparr <<<"${chkDnsArr[$i]}"  # 将记录分割成 ID 和 IP 地址
      delDnsArr+=(${sparr[0]})  # 将记录 ID 添加到待删除数组中
    fi
  done
}

# 函数：实际执行删除操作
RealDelDns() {
  delDnsApi="https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records"

  FilterRec  # 过滤待删除的 DNS 记录
  for index in "${!delDnsArr[@]}"; do
    record_id=${delDnsArr[$index]}
    # 获取旧的 IP 地址
    old_ip=$(echo "${chkDnsArr[$index]}" | cut -d':' -f2)
    # 发出删除请求
    rt=$(curl -s -X DELETE "${delDnsApi}/$record_id" -H "Content-Type: application/json" -H "X-Auth-Email: $x_email" -H "X-Auth-Key: $api_key")
    succ=$(echo $rt | jq -r ".success")
    if [ "$succ" = "true" ]; then
      echo "成功从 $domain 删除旧 $record_type 记录"
    else
      echo "从 $domain 删除旧 $record_type 记录失败"
    fi
  done
}

# 函数：向 Cloudflare 添加新的 DNS 记录
InsertCF() {
  local ipAddr=$1
  local domain=$2
  if [[ $ipAddr =~ $ipv4Regex ]]; then
    recordType="A"  # 如果是 IPv4 地址，则记录类型为 A
  else
    recordType="AAAA"  # 如果是 IPv6 地址，则记录类型为 AAAA
  fi

  createDnsApi="https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records"
  res=$(curl -s -X POST "$createDnsApi" -H "X-Auth-Email:$x_email" -H "X-Auth-Key:$api_key" -H "Content-Type:application/json" --data "{\"type\":\"$recordType\",\"name\":\"$domain\",\"content\":\"$ipAddr\",\"proxied\":$proxy}")
  resSuccess=$(echo "$res" | jq -r ".success")

  if [[ "$resSuccess" = "true" ]]; then
    echo "成功添加 $ipAddr 到 $domain"
    return 0
  else
    code=$(echo "$res" | jq -r ".errors[0].code")
    error_message=$(echo "$res" | jq -r ".errors[0].message")
    # 如果出现错误代码 81057，表示已有相同记录，不需要更新
    if [ $code -eq 81057 ]; then
      excludeIp+=($ipAddr)
      echo "已有 [$ipAddr] IP 记录，不做更新"
      return 0
    else
      echo "添加 $ipAddr 到 $domain失败"
      echo "错误代码: $code"
      echo "错误信息: $error_message"
      return 1
    fi
  fi
}

# 函数：处理 IP 地址
process_ip() {
    local ip_type="$1"
    local url="$2"
    local max_lines="$3"
    local dns_type="$4"
    local cf_num="$5"

    stop_plugin $CLIEN

    # 检查URL是否为空
    if [ -z "$url" ]; then
        print_info "URL为空，跳过${ip_type}地址下载，直接运行CloudflareST"
    else
        # 获取 IP 地址并随机选择
        local attempt=1
        local grep_command

        if [ "$ip_type" = "IPv4" ]; then
            grep_command=(grep ".*\..*")
        else
            grep_command=(grep -v ".*\..*")
        fi

        while (( attempt <= max_retries )); do
            response=$(timeout $single_attempt_timeout curl -sL "$url")
            if [ $? -eq 0 ]; then
                echo "$response" | "${grep_command[@]}" | awk 'BEGIN {srand()} {print rand() "\t" $0}' | sort -n | cut -f2- | head -n "$max_lines" > ip.txt
                break  # 成功则跳出循环
            else
                print_error "获取 ${ip_type} 地址失败，重试 $attempt 次..."
                ((attempt++))
                sleep $retry_delay
            fi
        done

        if (( attempt > max_retries )); then
            print_error "获取 ${ip_type} 地址失败，已达到最大重试次数"
            return 1
        fi
    fi
    
    print_info "./CloudflareST $cf_command -dn $cf_num -p $cf_num"

    if ! ./CloudflareST $cf_command -dn $cf_num -p $cf_num; then
        print_error "CloudflareST 执行失败"
        return 1
    fi

    restart_plugin $CLIEN
    update_dns "$dns_type" "$cf_num"
    return 0
}

# 处理 IPv4
process_ipv4() {
    process_ip "IPv4" "$v4_url" "$max_ipv4_lines" "A" "$v4_num"
}

# 处理 IPv6
process_ipv6() {
    process_ip "IPv6" "$v6_url" "$max_ipv6_lines" "AAAA" "$v6_num"
}

# 更新DNS记录
update_dns() {
    local record_type="$1"
    local num_records="$2"

    # 只在非"未指定"模式下执行 Cloudflare 验证和更新
    if [ "$add_ddns" != "未指定" ]; then
        echo "开始验证 Cloudflare 账号..."

        for ((attempt=1; attempt<=max_login_retries; attempt++)); do
            echo "正在进行第 $attempt 次登录尝试..."
            
            res=$(timeout $max_single_login_time curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}" \
                -H "X-Auth-Email:$x_email" \
                -H "X-Auth-Key:$api_key" \
                -H "Content-Type:application/json")

            # 检查curl是否因超时而失败
            if [ $? -eq 124 ]; then
                echo "登录尝试超时，已达到单次最大等待时间 ${max_single_login_time} 秒"
                if [[ $attempt -lt $max_login_retries ]]; then
                    echo "等待 ${login_retry_delay} 秒后重试..."
                    sleep $login_retry_delay
                    continue
                else
                    echo "已达到最大重试次数 $max_login_retries"
                    return 1
                fi
            fi

            echo "收到 Cloudflare 响应"

            resSuccess=$(echo "$res" | jq -r ".success")
            if [[ $resSuccess == "true" ]]; then
                echo "Cloudflare 账号验证成功"
                break
            else
                error_message=$(echo "$res" | jq -r '.errors[0].message')
                echo "第 $attempt / $max_login_retries 次登录失败"
                echo "错误信息: ${error_message:-未知错误}"
                
                if [[ $attempt -lt $max_login_retries ]]; then
                    echo "等待 ${login_retry_delay} 秒后重试..."
                    sleep $login_retry_delay
                else
                    echo "登录失败，已达到最大重试次数 $max_login_retries"
                    echo "完整错误响应: $res"
                    return 1
                fi
            fi
        done

        # 开始更新域名
        echo "正在更新域名，请稍后..."
    fi

    x=0

    # 检查 $csvfile 文件是否存在且不为空
    if [ ! -f "$csvfile" ] || [ ! -s "$csvfile" ]; then
        echo "错误: $csvfile 文件不存在或为空，可能没有测速结果"
        echo "没有测速结果" > informlog
        return 1
    fi

    # 读取 IP 地址到数组
    mapfile -t ip_addresses < <(tail -n +2 "$csvfile" | head -n "$num_records" | cut -d',' -f1)
    ip_count=${#ip_addresses[@]}

    # 如果没有 IP 地址，则不进行任何操作
    if [ $ip_count -eq 0 ]; then
        echo "没有测速结果" > informlog
        return 1
    fi

    # 只在非"未指定"模式下执行 DNS 记录更新
    if [ "$add_ddns" != "未指定" ]; then
        # 删除旧记录
        for domain in "${domains[@]}"; do
            CheckDelCFDns "$domain" "$record_type"
            RealDelDns
        done

        # 添加新记录
        declare -A domain_ip_map
        ip_index=0
        domain_index=0

        while [ $ip_index -lt $ip_count ]; do
            current_domain=${domains[$domain_index]}
            current_ip=${ip_addresses[$ip_index]}
            
            InsertCF "$current_ip" "$current_domain"
            
            if [[ ! ${domain_ip_map[$current_domain]} ]]; then
                domain_ip_map[$current_domain]="$current_ip"
            else
                domain_ip_map[$current_domain]="${domain_ip_map[$current_domain]},$current_ip"
            fi

            ip_index=$((ip_index + 1))
            domain_index=$((domain_index + 1))
            
            if [ $domain_index -eq $domain_count ]; then
                domain_index=0
            fi
        done
    fi

    echo "完成 IP 更新!"

    # 创建 informlog 文件，包含测速结果
    > informlog
    if [ "$add_ddns" != "未指定" ]; then
        # 如果不是未指定模式，添加域名和 IP 的对应关系
        for domain in "${!domain_ip_map[@]}"; do
            echo "$domain=${domain_ip_map[$domain]}" >> informlog
        done
    else
        # 如果是未指定模式，将所有 IP 写入一行
        echo -n "未指定=" >> informlog
        printf "%s" "${ip_addresses[0]}" >> informlog
        for ((i=1; i<${#ip_addresses[@]}; i++)); do
            printf ",%s" "${ip_addresses[$i]}" >> informlog
        done
        echo "" >> informlog
    fi
}

# 用于处理 IP 更新和消息推送
process_ip_and_push() {
    local ip_type="$1"
    local process_func="$2"
    local num="$3"

    if [ "$num" -ne 0 ]; then
        if $process_func; then
            has_update=true
            # 处理消息推送
            if [ ! -z "$push_mod" ]; then
                if [ -f informlog ]; then
                    if ! ./cf_push.sh "$push_mod" "$config_file" "$hostnames" "$v4_num" "$v6_num" "$ip_type" "$csvfile" "$ddns_name"; then
                        print_error "${ip_type} 推送消息失败"
                    fi
                else
                    print_error "informlog 文件不存在，无法推送 ${ip_type} 消息"
                fi
            fi
        fi
    else
        echo "根据设置，跳过 ${ip_type} 测速"
    fi
}

# 主处理逻辑
main() {
    local has_update=false

    # 处理 IPv4
    process_ip_and_push "IPv4" process_ipv4 "$v4_num"

    # 处理 IPv6
    process_ip_and_push "IPv6" process_ipv6 "$v6_num"

}

# 执行主处理逻辑
main
