# opw-cloudflare

通过 OpenWrt 优选 IP 并解析到 Cloudflare

## 简介

通过 OpenWrt 路由器优选 Cloudflare 的 IP 地址,并将其自动更新到 Cloudflare DNS 记录中

## 脚本功能

- 自动扫描并测速 Cloudflare IP
- 自动更新 Cloudflare DNS 记录
- 自动推送测速和解析的结果
- 支持定期运行随时获得最新优选 IP

## 安装说明

安装依赖

`bash` `curl`

首次运行

```curl -ksSL https://ghp.ci/https://raw.githubusercontent.com/GuangYu-yu/opw-cloudflare/main/cfopw.sh | bash```

或者

```curl -ksSL https://gitlab.com/GuangYu-yu/opw-cloudflare/-/raw/main/cfopw.sh | bash```

后续运行

`bash cf`

## 文件说明

- `cf`: 主菜单脚本
- `cf_push.sh`: 推送消息服务
- `cfopw.sh`: 初始安装脚本
- `cf.yaml`: 配置文件
- `setup_cloudflarest.sh`: 获取 CloudflareST
- `start_ddns.sh`: 解析到 Cloudflare

## 特别功能

- 支持多个测速配置和多个 Cloudflare 账户
- 更加详细的推送消息
- 从 URL 获取最新 CIDR
- 支持同时设置 IPv4 和 IPv6 数量
- 假设解析组名称为`www`，那么可以通过`bash cf start www`立即进行测速和解析
