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
push_mod=${11}
clien=${12:-0}
config_file=${13}

# 删除 .csv 文件
if ! rm -rf *.csv; then
    print_error "无法删除 .csv 文件"
fi

# 组合主机名
hostnames=$(echo $hostname2 | tr ' ' '\n' | sed "s/$/.${hostname1}/" | tr '\n' ' ' | sed 's/ $//')
if [ -z "$hostnames" ]; then
    print_error "主机名组合失败"
    exit 1
fi

# 如果$v4_num和$v6_num同时大于0，那么赋值为0，否则赋值为1
if [ "$v4_num" -gt 0 ] && [ "$v6_num" -gt 0 ]; then
    new_variable=0
else
    new_variable=1
fi

GetProxName() {
  case "$clien" in
    0) CLIEN="" ;;
    1) CLIEN=passwall ;;
    2) CLIEN=passwall2 ;;
    3) CLIEN=shadowsocksr ;;
    4) CLIEN=openclash ;;
    5) CLIEN=shellcrash ;;
    6) CLIEN=neko ;;
    7) CLIEN=bypass ;;
    *) print_error "未知的插件类型: $clien"; exit 1 ;;
  esac
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
    fi
  fi
}

# 函数：重启插件
restart_plugin() {
  if [ -z "$CLIEN" ]; then
    print_info "根据配置，插件不会重启。"
    sleep 3s
  else
    if ! /etc/init.d/$CLIEN restart; then
        print_error "重启 $CLIEN 失败"
    else
        print_info "已重启 $CLIEN"
        print_info "为了确保 Cloudflare API 连接正常，DNS 记录更新将在 3 秒后开始。"
        sleep 3s
    fi
  fi
}

# 函数：处理脚本退出时的操作
handle_err() {
  if [ -n "$CLIEN" ]; then
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

# 判断 $v4_num 是否不为 0
if [ "$v4_num" -ne 0 ]; then
  multip=$v4_num
  stop_plugin $CLIEN
  
  if ! curl -sL "$v4_url" | grep -v ':' > ip.txt; then
    print_error "获取 IPv4 地址失败"
    exit 1
  fi
  
  if ! ./CloudflareST $cf_command -dn $v4_num -p $v4_num; then
    print_error "CloudflareST 执行失败"
    exit 1
  fi
  print_info "./CloudflareST $cf_command -dn $v4_num -p $v4_num"

  restart_plugin $CLIEN
  the_type=4
  if ! ./cf_ddns.sh "$x_email" "$zone_id" "$api_key" "$hostnames" "$v4_num" "$v6_num" "$the_type" "$new_variable" "$multip"; then
    print_error "cf_ddns.sh 执行失败"
    exit 1
  fi
  
  # 替换推送相关的代码
  # 推送消息
  if [ ! -z "$push_mod" ]; then
    if [ -f informlog ]; then
      pushmessage=$(cat informlog)
      if ! ./cf_push.sh "$push_mod" "$config_file" "$pushmessage"; then
        print_error "推送消息失败"
      fi
    else
      print_error "informlog 文件不存在，无法推送消息"
    fi
  fi
  rm -f informlog
fi

# 判断 $v6_num 是否不为 0
if [ "$v6_num" -ne 0 ]; then
  multip=$v6_num
  stop_plugin $CLIEN
  
  if ! curl -sL "$v6_url" | grep ':' > ip.txt; then
    print_error "获取 IPv6 地址失败"
    exit 1
  fi
  
  if ! ./CloudflareST $cf_command -dn $v6_num -p $v6_num; then
    print_error "CloudflareST 执行失败"
    exit 1
  fi
  print_info "./CloudflareST $cf_command -dn $v6_num -p $v6_num"

  restart_plugin $CLIEN
  the_type=6
  if ! ./cf_ddns.sh "$x_email" "$zone_id" "$api_key" "$hostnames" "$v4_num" "$v6_num" "$the_type" "$new_variable" "$multip"; then
    print_error "cf_ddns.sh 执行失败"
    exit 1
  fi
  
  # 推送消息
  if [ ! -z "$push_mod" ]; then
    if [ -f informlog ]; then
      pushmessage=$(cat informlog)
      if ! ./cf_push.sh "$push_mod" "$config_file" "$pushmessage"; then
        print_error "推送消息失败"
      fi
    else
      print_error "informlog 文件不存在，无法推送消息"
    fi
  fi
  rm -f informlog
fi
