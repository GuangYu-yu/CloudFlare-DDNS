#!/bin/bash

push_mod=$1
config_file=$2
pushmessage=$3

# 检查配置文件是否存在
if [ -z "$config_file" ] || [ ! -f "$config_file" ]; then
    echo "错误：配置文件不存在或未指定"
    exit 1
fi

# 从配置文件读取推送设置
read_push_settings() {
    local push_id=$1
    grep "push_name=($push_id)" "$config_file" | sed 's/^[^,]*,//; s/,[^,]*$//' | tr ',' '\n' | sed 's/^[^=]*=(\([^)]*\)).*/\1/'
}

# 检查 informlog 文件并读取内容
if [ ! -f "./informlog" ]; then
    echo "informlog 文件不存在"
    exit 1
fi

if [ ! -s "./informlog" ]; then
    echo "informlog 文件为空"
    message_text="没有推送信息"
else
    message_text=$(cat ./informlog)
fi

# 读取 result.csv 文件并格式化 IP 信息
if [ -f "result.csv" ]; then
    ip_info=$(awk -F',' 'BEGIN {
        print "IP 地址："
    }
    NR>1 {
        ips[NR-1] = $1
        loss[NR-1] = $4
        latency[NR-1] = $5
        speed[NR-1] = $6
        count++
    }
    END {
        for (i=1; i<=count; i++) print i ". " ips[i]
        print "———————————————————"
        print "丢包率："
        for (i=1; i<=count; i++) print i ". " loss[i]
        print "———————————————————"
        print "平均延迟："
        for (i=1; i<=count; i++) print i ". " latency[i] " ms"
        print "———————————————————"
        print "下载速度 (MB/s)："
        for (i=1; i<=count; i++) print i ". " speed[i]
        print "———————————————————"
        print "DNS 记录状态："
        for (i=1; i<=count; i++) print i ". 更新成功"
    }' result.csv)
    message_text="${ip_info}"
fi

# 设置 Telegram 和微信 API 的基础 URL
tgapi=${Proxy_TG:-"https://api.telegram.org"}
wxapi=${Proxy_WX:-"https://qyapi.weixin.qq.com"}

# 处理多个推送模式
IFS=' ' read -ra push_modes <<< "$push_mod"
for mode in "${push_modes[@]}"; do
    push_params=($(read_push_settings $mode))
    
    if [ ${#push_params[@]} -eq 0 ]; then
        echo "无法读取推送模式 $mode 的参数"
        continue
    fi

    case $mode in
        1)  # Telegram 推送
            telegram_bot_token=${push_params[0]}
            telegram_user_id=${push_params[1]}
            TGURL="$tgapi/bot${telegram_bot_token}/sendMessage"
            res=$(curl -s -X POST $TGURL -H "Content-type:application/json" -d "{\"chat_id\":\"$telegram_user_id\", \"parse_mode\":\"HTML\", \"text\":\"$message_text\"}")
            if [[ $(echo "$res" | jq -r ".ok") == "true" ]]; then
                echo "TG推送成功"
            else
                echo "TG推送失败，请检查网络或TG机器人token和ID"
            fi
            ;;
        2)  # PushPlus 推送
            pushplus_token=${push_params[0]}
            echo "正在进行 PushPlus 推送..."
            res=$(curl -s -X POST "http://www.pushplus.plus/send" \
                 -H "Content-Type: application/json" \
                 -d "{\"token\":\"${pushplus_token}\",\"title\":\"cf优选ip推送\",\"content\":\"${message_text}\",\"template\":\"html\"}")
            if [[ $(echo "$res" | jq -r ".code") == 200 ]]; then
                echo "PushPlus推送成功"
            else
                echo "PushPlus推送失败，错误信息：$(echo "$res" | jq -r ".msg")"
                echo "请检查pushplus_token是否填写正确"
            fi
            ;;
        3)  # Server 酱推送
            server_sendkey=${push_params[0]}
            res=$(curl -s -X POST "https://sctapi.ftqq.com/${server_sendkey}.send" -d "title=cf优选ip推送" -d "desp=${message_text}")
            if [[ $(echo "$res" | jq -r ".code") == 0 ]]; then
                echo "Server 酱推送成功"
            else
                echo "Server 酱推送失败，请检查Server 酱server_sendkey是否配置正确"
            fi
            ;;
        4)  # PushDeer 推送
            pushdeer_pushkey=${push_params[0]}
            res=$(curl -s -X POST "https://api2.pushdeer.com/message/push" -d "pushkey=${pushdeer_pushkey}" -d "text=cf优选ip推送" -d "desp=${message_text}")
            if [[ $(echo "$res" | jq -r ".code") == 0 ]]; then
                echo "PushDeer推送成功"
            else
                echo "PushDeer推送失败，请检查pushdeer_pushkey是否填写正确"
            fi
            ;;
        5)  # 企业微信推送
            wechat_corpid=${push_params[0]}
            wechat_secret=${push_params[1]}
            wechat_agentid=${push_params[2]}
            wechat_userid=${push_params[3]}
            access_token=$(curl -s -G "https://qyapi.weixin.qq.com/cgi-bin/gettoken" -d "corpid=$wechat_corpid" -d "corpsecret=$wechat_secret" | jq -r .access_token)
            res=$(curl -s -X POST "https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token=$access_token" -H "Content-Type: application/json" -d "{\"touser\":\"$wechat_userid\",\"msgtype\":\"text\",\"agentid\":$wechat_agentid,\"text\":{\"content\":\"$message_text\"}}")
            if [[ $(echo "$res" | jq -r ".errcode") == "0" ]]; then
                echo "企业微信推送成功"
            else
                echo "企业微信推送失败，请检查企业微信参数是否填写正确"
            fi
            ;;
        6)  # Synology Chat 推送
            synology_chat_url=${push_params[0]}
            res=$(curl -X POST "$synology_chat_url" -H "Content-Type: application/json" -d "{\"text\":\"$message_text\"}")
            if [[ $(echo "$res" | jq -r ".success") == "true" ]]; then
                echo "Synology_Chat推送成功"
            else
                echo "Synology_Chat推送失败，请检查synology_chat_url是否填写正确"
            fi
            ;;
        *)
            echo "未知的推送模式: $mode"
            ;;
    esac
done

exit 0
