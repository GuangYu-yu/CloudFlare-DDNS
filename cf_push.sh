#!/bin/bash

# 传入参数
push_mod=$1
config_file=$2
pushmessage=$3
hostnames=$4
v4_num=$5
v6_num=$6
ip_type=$7
csvfile=$8

# 设置超时时间
TIMEOUT=20

# 检查配置文件是否存在
if [ -z "$config_file" ] || [ ! -f "$config_file" ]; then
    echo "错误：配置文件不存在或未指定"
    exit 1
fi

# 从配置文件读取推送设置
read_push_settings() {
    local push_id=$1
    yq e ".push[] | select(.push_name == \"$push_mod\")" "$config_file"
}

# 检查 informlog 文件并读取内容
if [ ! -f "./informlog" ]; then
    echo "informlog 文件不存在"
    message_text="错误: informlog 文件不存在，无法获取更新信息"
elif [ ! -s "./informlog" ]; then
    echo "informlog 文件为空"
    message_text="错误: 没有更新信息"
else
    message_text=$(cat ./informlog)
fi

# 读取 $csvfile 文件的部分
if [ -f "$csvfile" ]; then
    ip_count=$(($ip_type == "IPv4" ? $v4_num : $v6_num))
    ip_info=$(awk -F',' -v domains="$hostnames" -v ip_count="$ip_count" -v ip_type="$ip_type" 'BEGIN {
        split(domains, domain_arr, " ")
        print ip_type " 地址："
    }
    NR>1 {
        if (NR-2 < ip_count) {  # 只处理实际解析的IP数量
            ips[NR-1] = $1
            latency[NR-1] = $5
            speed[NR-1] = $6
            count++
        }
    }
    END {
        for (i=1; i<=count; i++) print ips[i]
        print "━━━━━━━━━━━━━━━━━━━"
        print "域名："
        for (i=1; i<=length(domain_arr); i++) print domain_arr[i]
        print "━━━━━━━━━━━━━━━━━━━"
        print "平均延迟："
        for (i=1; i<=count; i++) print latency[i] " ms"
        print "━━━━━━━━━━━━━━━━━━━"
        print "下载速度："
        for (i=1; i<=count; i++) print speed[i] " MB/s"
    }' "$csvfile")
    message_text="${ip_info}"
else
    message_text="错误: 没有测速结果 ($csvfile 文件不存在)"
fi

# 设置 Telegram 和微信 API 的基础 URL
tgapi="https://api.telegram.org"
wxapi="https://qyapi.weixin.qq.com"

TGURL="$tgapi/bot${telegramBotToken}/sendMessage"
PushDeerURL="https://api2.pushdeer.com/message/push?pushkey=${PushDeerPushKey}"
WX_tkURL="$wxapi/cgi-bin/gettoken"
WXURL="$wxapi/cgi-bin/message/send?access_token="

# 处理多个推送模式
IFS=' ' read -ra push_modes <<< "$push_mod"
for mode in "${push_modes[@]}"; do
    case $mode in
        "不设置")
            echo "未配置推送"
            ;;
        "Telegram")  # Telegram 推送
            telegram_bot_token=$(yq e ".push[] | select(.push_name == \"Telegram\") | .telegram_bot_token" "$config_file")
            telegram_user_id=$(yq e ".push[] | select(.push_name == \"Telegram\") | .telegram_user_id" "$config_file")
            res=$(timeout $TIMEOUT curl -s -X POST "$TGURL" \
                -H "Content-type:application/json" \
                -d "{\"chat_id\":\"$telegram_user_id\", \"parse_mode\":\"HTML\", \"text\":\"$message_text\"}")

            if [ $? == 124 ]; then
                echo "TG_api 请求超时，请检查网络连接"
                continue
            fi

            if [[ $(echo "$res" | jq -r ".ok") == "true" ]]; then
                echo "Telegram 推送成功"
            else
                echo "Telegram 推送失败，请检查网络或TG机器人Token和ID"
            fi
            ;;
        "PushPlus")  # PushPlus 推送
            pushplus_token=$(yq e ".push[] | select(.push_name == \"PushPlus\") | .pushplus_token" "$config_file")

            res=$(timeout $TIMEOUT curl -s -X POST "http://www.pushplus.plus/send" \
                -H "Content-Type: application/json" \
                -d "{\"token\":\"${pushplus_token}\",\"title\":\"Cloudflare优选IP\",\"content\":\"${message_text}\",\"template\":\"html\"}")

            if [ $? == 124 ]; then
                echo "PushPlus 请求超时，请检查网络连接"
                continue
            fi

            if [[ $(echo "$res" | jq -r ".code") == 200 ]]; then
                echo "PushPlus 推送成功"
            else
                echo "PushPlus 推送失败：$(echo "$res" | jq -r ".msg")"
            fi
            ;;
        "Server酱")  # Server酱 推送
            server_sendkey=$(yq e ".push[] | select(.push_name == \"Server酱\") | .server_sendkey" "$config_file")
            res=$(timeout $TIMEOUT curl -s -X POST "https://sctapi.ftqq.com/${server_sendkey}.send" \
                -d "title=Cloudflare优选IP" \
                -d "desp=${message_text}")

            if [ $? == 124 ]; then
                echo "Server酱 请求超时，请检查网络连接"
                continue
            fi

            if [[ $(echo "$res" | jq -r ".code") == 0 ]]; then
                echo "Server酱 推送成功"
            else
                echo "Server酱 推送失败：$(echo "$res" | jq -r ".message")"
            fi
            ;;
        "PushDeer")  # PushDeer 推送
            pushdeer_pushkey=$(yq e ".push[] | select(.push_name == \"PushDeer\") | .pushdeer_pushkey" "$config_file")
            res=$(timeout $TIMEOUT curl -s -X POST "$PushDeerURL" \
                -d "text=Cloudflare优选IP" \
                -d "desp=${message_text}")

            if [ $? == 124 ]; then
                echo "PushDeer 请求超时，请检查网络连接"
                continue
            fi

            if [[ $(echo "$res" | jq -r ".code") == 0 ]]; then
                echo "PushDeer 推送成功"
            else
                echo "PushDeer 推送失败：$(echo "$res" | jq -r ".error")"
            fi
            ;;
        "企业微信")  # 企业微信 推送
            wechat_corpid=$(yq e ".push[] | select(.push_name == \"企业微信\") | .wechat_corpid" "$config_file")
            wechat_secret=$(yq e ".push[] | select(.push_name == \"企业微信\") | .wechat_secret" "$config_file")
            wechat_agentid=$(yq e ".push[] | select(.push_name == \"企业微信\") | .wechat_agentid" "$config_file")
            wechat_userid=$(yq e ".push[] | select(.push_name == \"企业微信\") | .wechat_userid" "$config_file")
            # 检查 access_token 是否存在且有效
            CHECK="false"
            if [ -f ".access_token" ]; then
                if [[ $(date -d "$(date "+%Y-%m-%d %H:%M:%S")" +%s) -le $(cat .access_token | jq -r ".expires") ]]; then
                    echo "企业微信 access_token 在有效期内"
                    CHECK="true"
                    access_token=$(cat .access_token | jq -r ".access_token")
                fi
            fi

            # 如果 access_token 不存在或已过期，重新获取
            if [ "$CHECK" != "true" ]; then
                token_res=$(timeout $TIMEOUT curl -s -X POST "$WX_tkURL" \
                    -H "Content-type:application/json" \
                    -d "{\"corpid\":\"$wechat_corpid\", \"corpsecret\":\"$wechat_secret\"}")

                if [ $? == 124 ]; then
                    echo "企业微信获取Token超时，请检查网络连接"
                    continue
                fi

                if [[ $(echo "$token_res" | jq -r ".errcode") == "0" ]]; then
                    echo "access_token 获取成功"
                    access_token=$(echo "$token_res" | jq -r ".access_token")
                    # 保存 access_token 和过期时间（2小时后）
                    echo "{\"access_token\":\"$access_token\", \"expires\":\"$(($(date -d "$(date "+%Y-%m-%d %H:%M:%S")" +%s) + 7200))\"}" > .access_token
                    CHECK="true"
                else
                    echo "access_token 获取失败，请检查 CORPID 和 SECRET"
                    continue
                fi
            fi

            # 发送消息
            res=$(timeout $TIMEOUT curl -s -X POST "${WXURL}${access_token}" \
                -H "Content-Type: application/json" \
                -d "{\"touser\":\"$wechat_userid\",\"msgtype\":\"text\",\"agentid\":$wechat_agentid,\"text\":{\"content\":\"$message_text\"}}")

            if [ $? == 124 ]; then
                echo "企业微信发送消息超时，请检查网络连接"
                continue
            fi

            # 处理不同的错误情况
            case $(echo "$res" | jq -r ".errcode") in
                "0")
                    echo "企业微信推送成功"
                    ;;
                "81013")
                    echo "企业微信 USERID 填写错误，请检查后重试"
                    ;;
                "60020")
                    echo "企业微信应用未配置本机IP地址，请在企业微信后台添加IP白名单"
                    ;;
                *)
                    echo "企业微信推送失败：$(echo "$res" | jq -r ".errmsg")"
                    ;;
            esac
            ;;
        "Synology-Chat")  # Synology-Chat 推送
            synology_chat_url=$(yq e ".push[] | select(.push_name == \"Synology-Chat\") | .synology_chat_url" "$config_file")
            res=$(timeout $TIMEOUT curl -s -X POST "$synology_chat_url" \
                -H "Content-Type: application/json" \
                -d "{\"text\":\"$message_text\"}")

            if [ $? == 124 ]; then
                echo "Synology-Chat 请求超时，请检查网络连接"
                continue
            fi

            if [[ $(echo "$res" | jq -r ".success") == "true" ]]; then
                echo "Synology-Chat 推送成功"
            else
                echo "Synology-Chat 推送失败：$(echo "$res" | jq -r ".error")"
            fi
            ;;
        "Github")  # Github 推送
            # 获取 Github 配置
            file_url=$(yq e ".push[] | select(.push_name == \"Github\") | .file_url" "$config_file")
            port=$(yq e ".push[] | select(.push_name == \"Github\") | .port" "$config_file")
            remark=$(yq e ".push[] | select(.push_name == \"Github\") | .remark" "$config_file")

            # 解析 Github URL
            if [[ "$file_url" =~ ^https://raw\.githubusercontent\.com/([^/]+)/([^/]+)/refs/heads/([^/]+)/(.+)\?token=(.+)$ ]]; then
                TOKEN="${BASH_REMATCH[5]}"
                REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
                BRANCH="${BASH_REMATCH[3]}"
                REMOTE_PATH="${BASH_REMATCH[4]}"
            else
                echo "参数错误"
                continue
            fi

            # 处理当前的 IP 地址
            processed_ips=""
            while IFS= read -r ip; do
                if [[ "$ip" =~ .*:.* ]]; then
                    # IPv6 地址
                    processed_ip="[${ip}]:${port}#${remark}"
                else
                    # IPv4 地址
                    processed_ip="${ip}:${port}#${remark}"
                fi
                processed_ips="${processed_ips}${processed_ip}\n"
            done < <(cat informlog)

            # 去除空行和重复行
            final_content=$(echo -e "$processed_ips" | sed '/^$/d' | sort -u)

            # base64 编码
            ENCODED_CONTENT=$(echo -n "$final_content" | base64 | tr -d '\n')

            # 检查文件是否存在
            CHECK_RESPONSE=$(curl -s -H "Authorization: token $TOKEN" \
                "https://api.github.com/repos/$REPO/contents/$REMOTE_PATH")

            if echo "$CHECK_RESPONSE" | jq -e '.message == "Not Found"' > /dev/null; then
                # 文件不存在，创建新文件
                RESPONSE=$(timeout $TIMEOUT curl -s -X PUT \
                    -H "Authorization: token $TOKEN" \
                    -H "Accept: application/vnd.github.v3+json" \
                    -d "{\"message\":\"创建 Cloudflare 优选 IP 文件\",\"content\":\"$ENCODED_CONTENT\",\"branch\":\"$BRANCH\"}" \
                    "https://api.github.com/repos/$REPO/contents/$REMOTE_PATH")
            else
                # 文件存在，更新文件
                SHA=$(echo "$CHECK_RESPONSE" | jq -r '.sha')
                
                # 获取现有内容并合并
                current_content=$(echo "$CHECK_RESPONSE" | jq -r '.content' | base64 -d)
                if [ -n "$current_content" ]; then
                    # 从现有内容中删除相同 port 和 remark 的行
                    filtered_content=$(echo -e "$current_content" | grep -v ":${port}#${remark}$")
                    # 合并内容
                    new_content="${filtered_content}\n${processed_ips}"
                    # 去除空行和重复行
                    final_content=$(echo -e "$new_content" | sed '/^$/d' | sort -u)
                    # 重新编码
                    ENCODED_CONTENT=$(echo -n "$final_content" | base64 | tr -d '\n')
                fi

                RESPONSE=$(timeout $TIMEOUT curl -s -X PUT \
                    -H "Authorization: token $TOKEN" \
                    -H "Accept: application/vnd.github.v3+json" \
                    -d "{\"message\":\"更新 Cloudflare 优选 IP\",\"content\":\"$ENCODED_CONTENT\",\"sha\":\"$SHA\",\"branch\":\"$BRANCH\"}" \
                    "https://api.github.com/repos/$REPO/contents/$REMOTE_PATH")
            fi

            if [ $? == 124 ]; then
                echo "Github 提交超时，请检查网络连接"
                continue
            fi

            if echo "$RESPONSE" | grep -q '"commit"'; then
                echo "Github 推送成功"
            else
                echo "Github 推送失败：$(echo "$RESPONSE" | jq -r ".message")"
            fi
            ;;
        *)
            echo "未知的推送模式: $mode"
            ;;
    esac
done

exit 0
