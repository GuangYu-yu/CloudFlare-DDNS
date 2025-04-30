#!/bin/bash

# 根据参数决定调用哪个功能
case "$1" in
    "start")
        shift
        /path/to/start_ddns.sh "$@"
        ;;
    "push") 
        shift
        /path/to/cf_push.sh "$@"
        ;;
    *)
        /path/to/cf "$@"
        ;;
esac