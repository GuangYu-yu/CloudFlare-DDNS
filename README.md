# opw-cloudflare

通过 OpenWrt 优选 IP 并解析到 Cloudflare

## 项目简介

通过 OpenWrt 路由器优选 Cloudflare 的 IP 地址,并将其自动更新到 Cloudflare DNS 记录中。不止OpenWrt，大部分功能在Linux上都适用。

## 功能特点

- 自动扫描并测试 Cloudflare IP
- 选择最优 IP 地址
- 自动更新 Cloudflare DNS 记录
- 支持定期运行以保持最佳性能

## 安装说明

### 初次安装

运行以下命令进行初次安装:

安装依赖

`bash` `curl`

首次运行

```curl -ksSL https://ghp.ci/https://raw.githubusercontent.com/GuangYu-yu/opw-cloudflare/main/cfopw.sh | bash```

后续运行

`bash cf.sh`

## 文件说明

- `cf.sh`: 主菜单脚本
- `cf_push.sh`: 推送消息服务
- `cfopw.sh`: 初始安装脚本
- `cf.yaml`: 配置文件
- `setup_cloudflarest.sh`: 获取CloudflareST
- `start_ddns.sh`: 解析到Cloudflare

