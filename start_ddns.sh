#!/bin/bash

# 传入变量
x_email=$1
zone_id=$2
api_key=$3
hostname1=$4
hostname2=$5
v4_num=$6
v6_num=$7
cf_command=$8
v4_url=$9
v6_url=${10}
push_mod=${11:-0}
configfile=cf.yaml
clien=${12:-0}

# 删除 .csv 文件
rm -rf *.csv

# 组合主机名
hostnames=$(echo $hostname2 | tr ' ' '\n' | sed "s/^/${hostname1}/" | tr '\n' ' ' | sed 's/ $//')

# 如果$v4_num和$v6_num同时大于0，那么赋值为0，否则赋值为1，用于之后的ipv6记录解析前不会进行删除，赋值为0意味着不进行删除,为1意味着删除
if [ "$v4_num" -gt 0 ] && [ "$v6_num" -gt 0 ]; then
    new_variable=0
else
    new_variable=1
fi

GetProxName() {
  case "$clien" in
    0) CLIEN="" ;;               # 如果配置为0，设置CLIEN为空
    1) CLIEN=passwall ;;        # 如果配置为1，设置CLIEN为passwall
    2) CLIEN=passwall2 ;;       # 如果配置为2，设置CLIEN为passwall2
    3) CLIEN=shadowsocksr ;;    # 如果配置为3，设置CLIEN为shadowsocksr
    4) CLIEN=openclash ;;       # 如果配置为4，设置CLIEN为openclash
    5) CLIEN=shellcrash ;;      # 如果配置为5，设置CLIEN为shellcrash
    6) CLIEN=neko ;;            # 如果配置为6，设置CLIEN为nekoclash
    7) CLIEN=bypass ;;          # 如果配置为7，设置CLIEN为bypass
  esac
}

# 函数：停止插件
stop_plugin() {
  if [ -z "$CLIEN" ]; then   # 如果CLIEN为空
    echo "按配置不停止插件"
  else
    /etc/init.d/$CLIEN stop
    echo "停止 $CLIEN"
  fi
}

# 函数：重启插件
restart_plugin() {
  if [ -z "$CLIEN" ]; then   # 如果CLIEN为空
    echo "根据配置，插件不会重启。"
    sleep 3s
  else
    /etc/init.d/$CLIEN restart
    echo "已重启 $CLIEN"
    echo "为了确保 Cloudflare API 连接正常，DNS 记录更新将在 3 秒后开始。"
    sleep 3s
  fi
}

# 函数：处理脚本退出时的操作
handle_err() {
  # 如果CLIEN不为空，则恢复背景进程
  if [ -n "$CLIEN" ]; then
    echo "恢复后台进程"
    /etc/init.d/$CLIEN start
  fi
}

# 捕获脚本退出信号（HUP, INT, TERM, EXIT），调用handle_err函数
trap handle_err HUP INT TERM EXIT

# 获取CLIEN的值
GetProxName

# 判断 $v4_num 是否不为 0
if [ "$v4_num" -ne 0 ]; then
  multip=$v4_num
  stop_plugin $CLIEN
  
  curl -sL "$v4_url" | grep -v ':' > ip.txt
  ./CloudflareST $cf_command -dn $v4_num -p $v4_num
  echo "./CloudflareST $cf_command -dn $v4_num -p $v4_num"

  restart_plugin $CLIEN
  the_type=4
  source ./cf_ddns
  # 生成一个名为informlog的临时文件作为推送的内容
  pushmessage=$(cat informlog)
  echo $pushmessage
  # 根据配置决定推送消息的类型
  if [ ! -z "$push_mod" ]; then
    if [[ $push_mod -ge 1 && $push_mod -le 6 ]]; then
      source ./cf_push "$push_mod"
    else
      echo "推送方式出错"
    fi
  fi
  rm -f informlog
fi

# ==============================================================================

# 判断 $v6_num 是否不为 0
if [ "$v6_num" -ne 0 ]; then
  multip=$v6_num
  stop_plugin $CLIEN
  
  curl -sL "$v6_url" | grep ':' > ip.txt
  ./CloudflareST $cf_command -dn $v6_num -p $v6_num
  echo "./CloudflareST $cf_command -dn $v6_num -p $v6_num"

  restart_plugin $CLIEN
  the_type=6
  source ./cf_ddns
  # 生成一个名为informlog的临时文件作为推送的内容
  pushmessage=$(cat informlog)
  echo $pushmessage
  # 根据配置决定推送消息的类型
  if [ ! -z "$push_mod" ]; then
    if [[ $push_mod -ge 1 && $push_mod -le 6 ]]; then
      source ./cf_push "$push_mod"
    else
      echo "推送方式出错"
    fi
  fi
  rm -f informlog
fi