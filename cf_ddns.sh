#!/bin/bash

# 接收参数
x_email=$1
zone_id=$2
api_key=$3
hostnames=$4
v4_num=$5
v6_num=$6
the_type=$7
new_variable=$8
multip=$9

# IPv4 地址的正则表达式
ipv4Regex="((25[0-5]|(2[0-4]|1{0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])"

# 默认关闭 Cloudflare 的代理功能
proxy="false"

# 初始化数组
chkDnsArr=()
delDnsArr=()
excludeIp=()

# 检查 Cloudflare 上的 DNS 记录
CheckDelCFDns() {
    local CDNhostname=$1
    listDnsApi="https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?name=${CDNhostname}"
    res=$(curl -s -X GET "$listDnsApi" -H "X-Auth-Email:$x_email" -H "X-Auth-Key:$api_key" -H "Content-Type:application/json")
    total_ct=$(echo "$res" | jq -r ".result_info.total_count")

    if ((total_ct > 1 || multFlag == 1)); then
        for ((i = 0; i < total_ct; i++)); do
            record_id=$(echo "$res" | jq -r ".result[$i].id")
            ip=$(echo "$res" | jq -r ".result[$i].content")
            chkDnsArr+=("$record_id"":""$ip")
        done
    fi
}

# 检查 DNS 记录是否在排除列表中
findRecInExcludeArr() {
    local rec=$1
    local sparr=()
    IFS=':' read -ra sparr <<<"$rec"
    for ip in "${excludeIp[@]}"; do
        if [ "${sparr[1]}" == "$ip" ]; then
            return 0
        fi
    done
    return 1
}

# 过滤待删除的 DNS 记录
FilterRec() {
    delDnsArr=()
    for i in "${!chkDnsArr[@]}"; do
        findRecInExcludeArr "${chkDnsArr[$i]}"
        if [ $? -eq 1 ]; then
            local sparr=()
            IFS=':' read -ra sparr <<<"${chkDnsArr[$i]}"
            delDnsArr+=(${sparr[0]})

            if [[ ${sparr[1]} =~ $ipv4Regex ]]; then
                echo "正在删除IPv4记录：${sparr[1]}"
            else
                echo "正在删除IPv6记录：${sparr[1]}"
            fi
        fi
    done
}

# 执行删除操作
RealDelDns() {
  delDnsApi="https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records"

  FilterRec  # 过滤待删除的 DNS 记录
  for index in "${!delDnsArr[@]}"; do
    record_id=${delDnsArr[$index]}
    # 发出删除请求
    rt=$(curl -s -X DELETE "${delDnsApi}/$record_id" -H "Content-Type: application/json" -H "X-Auth-Email: $x_email" -H "X-Auth-Key: $api_key")
    succ=$(echo $rt | jq -r ".success")
    if [ "$succ" != "true" ]; then
      echo "删除 DNS 记录失败，可能引起后续更新问题，强制退出"
      exit 1
    fi
  done
}

# 添加新的 DNS 记录
InsertCF() {
    local CDNhostname=$1
    local ipAddr=$2
    echo "正在添加IP记录：$ipAddr"
    recordType=$(if [[ $ipAddr =~ $ipv4Regex ]]; then echo "A"; else echo "AAAA"; fi)
    createDnsApi="https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records"
    res=$(curl -s -X POST "$createDnsApi" -H "X-Auth-Email:$x_email" -H "X-Auth-Key:$api_key" -H "Content-Type:application/json" --data "{\"type\":\"$recordType\",\"name\":\"$CDNhostname\",\"content\":\"$ipAddr\",\"proxied\":$proxy}")
    resSuccess=$(echo "$res" | jq -r ".success")

    if [[ "$resSuccess" = "true" ]]; then
        echo "添加IP记录成功：$ipAddr"
    else
        code=$(echo "$res" | jq -r ".errors[0].code")
        if [ $code -eq 81057 ]; then
            excludeIp+=($ipAddr)
            echo "已有 [$ipAddr] IP 记录，不做更新"
        else
            echo "添加IP记录失败：$ipAddr"
        fi
    fi
}

# 更新或插入 DNS 记录
UpInsetCF() {
    local CDNhostname=$1
    local ipAddr=$2
    echo "正在添加IP记录：$ipAddr"
    recordType=$(if [[ $ipAddr =~ $ipv4Regex ]]; then echo "A"; else echo "AAAA"; fi)
    listDnsApi="https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?type=${recordType}&name=${CDNhostname}"
    createDnsApi="https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records"

    res=$(curl -s -X GET "$listDnsApi" -H "X-Auth-Email:$x_email" -H "X-Auth-Key:$api_key" -H "Content-Type:application/json")
    recordId=$(echo "$res" | jq -r ".result[0].id")
    recordIp=$(echo "$res" | jq -r ".result[0].content")

    if [[ $recordIp = "$ipAddr" ]]; then
        echo "IP记录已存在，无需更新：$ipAddr"
        excludeIp+=($ipAddr)
    elif [[ $recordId = "null" ]]; then
        res=$(curl -s -X POST "$createDnsApi" -H "X-Auth-Email:$x_email" -H "X-Auth-Key:$api_key" -H "Content-Type:application/json" --data "{\"type\":\"$recordType\",\"name\":\"$CDNhostname\",\"content\":\"$ipAddr\",\"proxied\":$proxy}")
        resSuccess=$(echo "$res" | jq -r ".success")
    else
        updateDnsApi="https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${recordId}"
        res=$(curl -s -X PUT "$updateDnsApi" -H "X-Auth-Email:$x_email" -H "X-Auth-Key:$api_key" -H "Content-Type:application/json" --data "{\"type\":\"$recordType\",\"name\":\"$CDNhostname\",\"content\":\"$ipAddr\",\"proxied\":$proxy}")
        resSuccess=$(echo "$res" | jq -r ".success")
        excludeIp+=($ipAddr)
    fi

    if [[ "$resSuccess" = "true" ]]; then
        echo "添加IP记录成功：$ipAddr"
    else
        echo "添加IP记录失败：$ipAddr"
    fi
}

# 主程序开始
max_retries=10 # 最大重试次数
retry_delay=3 # 重试延迟时间

echo "开始验证 Cloudflare 账号..."

for ((attempt=1; attempt<=max_retries; attempt++)); do
    echo "正在进行第 $attempt 次登录尝试..."
    res=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}" \
        -H "X-Auth-Email:$x_email" \
        -H "X-Auth-Key:$api_key" \
        -H "Content-Type:application/json")

    echo "收到 Cloudflare 响应"

    resSuccess=$(echo "$res" | jq -r ".success")
    if [[ $resSuccess == "true" ]]; then
        echo "Cloudflare 账号验证成功"
        break
    else
        error_message=$(echo "$res" | jq -r '.errors[0].message')
        echo "第 $attempt / $max_retries 次登陆失败"
        echo "错误信息: ${error_message:-未知错误}"
        if [[ $attempt -lt $max_retries ]]; then
            sleep $retry_delay
        else
            echo "登录失败，已达到最大重试次数 $max_retries"
            echo "完整错误响应: $res"
            exit 1
        fi
    fi
done

# 设置 multip 和 multFlag
if [ -z $multip ]; then
    multip=1
    multFlag=0
else
    multFlag=1
fi

echo "开始更新域名流程..."
read -ra domains <<< "$hostnames"
domain_num=${#domains[@]}

x=0
csvfile="result.csv"

while [[ ${x} -lt $domain_num ]]; do
    CDNhostname="${domains[$x]}"
    echo "正在处理域名: $CDNhostname"
    echo "————————————————"
    
    if [ ! -e $csvfile ]; then
        echo "警告: $csvfile 文件不存在，跳过当前域名"
        x=$((x + 1))
        continue
    fi

    CheckDelCFDns "$CDNhostname"

    if [ "$the_type" = "6" ] && [ "$new_variable" = "0" ]; then
        echo "同时解析IPv4和IPv6，跳过删除IP记录"
        echo "————————————————"
    else
        echo "开始删除旧的IP记录"
        RealDelDns
        echo "————————————————"
    fi
    echo "开始添加新的IP记录"

    lineNo=0
    ipcount=0
    while read -r line; do
        ((lineNo++))
        if ((lineNo == 1)); then continue; fi
        IFS=, read -ra fields <<<"$line"
        ipAddr=${fields[0]}

        ((ipcount++))
        if ((multFlag == 1)); then
            InsertCF "$CDNhostname" "$ipAddr"
        else
            UpInsetCF "$CDNhostname" "$ipAddr"
        fi

        if ((ipcount >= multip)); then break; fi
    done < $csvfile

    echo "————————————————"
    x=$((x + 1))
    sleep 1s
done

echo "更新进程已完成"

exit 0
