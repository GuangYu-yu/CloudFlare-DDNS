#!/bin/bash
set -e

[ "$#" -lt 5 ] && echo "用法: $0 用户 仓库 分支 文件 可执行程序 [重复多组]" && exit 1

while [ "$#" -ge 5 ]; do
  U=$1 P=$2 B=$3 F=$4 E=$5
  shift 5

  (
    echo "下载 $E ..."

    MAX_RETRIES=3
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
      if curl -fsSL -o "$F" "https://github.com/$U/$P/releases/download/$B/$F"; then
        if [ -s "$F" ]; then
          break
        fi
      fi
      RETRY_COUNT=$((RETRY_COUNT+1))
      echo "下载失败，重试 $RETRY_COUNT/$MAX_RETRIES..."
      sleep 2
    done

    if [ ! -s "$F" ]; then
      echo "下载 $F 失败，跳过 $E"
      exit 1
    fi

    tar -zxf "$F" && rm -f "$F"
    chmod +x "$E"
    echo "$E 获取成功！"
  ) &
done

wait
