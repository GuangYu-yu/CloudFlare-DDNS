# 🚀 CloudFlare-DDNS

<p align="center">
  <a href="https://github.com/GuangYu-yu/CloudFlare-DDNS">
    <img src="https://img.shields.io/github/stars/GuangYu-yu/CloudFlare-DDNS?style=social" alt="GitHub Stars">
  </a>
  <a href="https://github.com/GuangYu-yu/CloudFlare-DDNS/forks">
    <img src="https://img.shields.io/github/forks/GuangYu-yu/CloudFlare-DDNS?style=social" alt="GitHub Forks">
  </a>
  <a href="https://github.com/GuangYu-yu/CloudFlare-DDNS/releases">
    <img src="https://img.shields.io/github/downloads/GuangYu-yu/CloudFlare-DDNS/total?style=flat-square&logo=github" alt="GitHub Downloads">
  </a>
  <a href="https://deepwiki.com/GuangYu-yu/CloudFlare-DDNS">
    <img src="https://deepwiki.com/badge.svg" alt="Ask DeepWiki">
  </a>
    <img src="https://img.shields.io/badge/Ask_Zread-_.svg?style=flat&color=00b0aa&labelColor=000000&logo=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPHN2ZyB3aWR0aD0iMTYiIGhlaWdodD0iMTYiIHZpZXdCb3g9IjAgMCAxNiAxNiIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHBhdGggZD0iTTQuOTYxNTYgMS42MDAxSDIuMjQxNTZDMS44ODgxIDEuNjAwMSAxLjYwMTU2IDEuODg2NjQgMS42MDE1NiAyLjI0MDFWNC45NjAxQzEuNjAxNTYgNS4zMTM1NiAxLjg4ODEgNS42MDAxIDIuMjQxNTYgNS42MDAxSDQuOTYxNTZDNS4zMTUwMiA1LjYwMDEgNS42MDE1NiA1LjMxMzU2IDUuNjAxNTYgNC45NjAxVjIuMjQwMUM1LjYwMTU2IDEuODg2NjQgNS4zMTUwMiAxLjYwMDEgNC45NjE1NiAxLjYwMDFaIiBmaWxsPSIjZmZmIi8%2BCjxwYXRoIGQ9Ik00Ljk2MTU2IDEwLjM5OTlIMi4yNDE1NkMxLjg4ODEgMTAuMzk5OSAxLjYwMTU2IDEwLjY4NjQgMS42MDE1NiAxMS4wMzk5VjEzLjc1OTlDMS42MDE1NiAxNC4xMTM0IDEuODg4MSAxNC4zOTk5IDIuMjQxNTYgMTQuMzk5OUg0Ljk2MTU2QzUuMzE1MDIgMTQuMzk5OSA1LjYwMTU2IDE0LjExMzQgNS42MDE1NiAxMy43NTk5VjExLjAzOTlDNS42MDE1NiAxMC42ODY0IDUuMzE1MDIgMTAuMzk5OSA0Ljk2MTU2IDEwLjM5OTlaIiBmaWxsPSIjZmZmIi8%2BCjxwYXRoIGQ9Ik0xMy43NTg0IDEuNjAwMUgxMS4wMzg0QzEwLjY4NSAxLjYwMDEgMTAuMzk4NCAxLjg4NjY0IDEwLjM5ODQgMi4yNDAxVjQuOTYwMUMxMC4zOTg0IDUuMzEzNTYgMTAuNjg1IDUuNjAwMSAxMS4wMzg0IDUuNjAwMUgxMy43NTg0QzE0LjExMTkgNS42MDAxIDE0LjM5ODQgNS4zMTM1NiAxNC4zOTg0IDQuOTYwMVYyLjI0MDFDMTQuMzk4NCAxLjg4NjY0IDE0LjExMTkgMS42MDAxIDEzLjc1ODQgMS42MDAxWiIgZmlsbD0iI2ZmZiIvPgo8cGF0aCBkPSJNNCAxMkwxMiA0TDQgMTJaIiBmaWxsPSIjZmZmIi8%2BCjxwYXRoIGQ9Ik00IDEyTDEyIDQiIHN0cm9rZT0iI2ZmZiIgc3Ryb2tlLXdpZHRoPSIxLjUiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIvPgo8L3N2Zz4K&logoColor=ffffff" alt="zread">
  </a>
</p>

## 📖 项目简介

主要用于在OpenWrt优选IP，通过集成[CloudflareST-Rust](https://github.com/GuangYu-yu/CloudflareST-Rust)实现Cloudflare IP地址的自动测速与优选，并将最优IP自动更新到Cloudflare DNS记录。

## ✨ 功能特性

| 功能类别 | 具体特性 |
|---------|---------|
| 🌐 **IP优选** | • 自动测速CloudflareIP<br>• 支持IPv4/IPv6优选<br>• 自定义测速参数 |
| 🔄 **DNS管理** | • 自动更新Cloudflare DNS记录<br>• 支持多个域名和子域名<br>• 批量解析管理 |
| 📱 **消息推送** | • 多种推送途径<br>• 自定义推送内容 |
| 📊 **数据管理** | • 支持GitHub提交（需要令牌）<br> |
| ⚙️ **灵活配置** | • YAML配置文件<br>• 多账户支持<br>• 可直接运行 ./CFRS [解析组]<br> |

<img width="751" height="930" alt="演示图" src="https://gitee.com/zhxdcyy/CloudFlare-DDNS/raw/master/演示.png" />

## 🔧 安装方式

### CloudflareST-Rust + CFRS
```bash
curl -ksSL https://github.com/GuangYu-yu/CloudFlare-DDNS/releases/download/setup/cfopw.sh | bash
```

或者

```bash
bash -c 'ARCH=$( [ "$(uname -m)" = x86_64 ] && echo amd64 || echo arm64 ); curl -fsSL https://github.com/GuangYu-yu/CloudFlare-DDNS/releases/download/setup/setup.sh | bash -s -- GuangYu-yu CloudflareST-Rust main-latest CloudflareST-Rust_linux_$ARCH.tar.gz CloudflareST-Rust GuangYu-yu CloudFlare-DDNS main-latest CFRS_linux_$ARCH.tar.gz CFRS'
```

### CFRS

```bash
bash -c 'ARCH=$( [ "$(uname -m)" = x86_64 ] && echo amd64 || echo arm64 ); curl -fsSL https://github.com/GuangYu-yu/CloudFlare-DDNS/releases/download/setup/setup.sh | bash -s -- GuangYu-yu CloudFlare-DDNS main-latest CFRS_linux_$ARCH.tar.gz CFRS'
```

## 📄 配置文件结构 (`cf.yaml`)

```yaml
# 账户信息配置
account:
  - account_name: "账户"           # 账户标识名称
    x_email: "your@email.com"        # Cloudflare注册邮箱
    zone_id: "your_zone_id"          # 域名对应的Zone ID
    api_key: "your_api_key"          # Cloudflare API密钥

# DNS解析配置
resolve:
  - add_ddns: "账户"              # 关联的账户名称
    ddns_name: "域名解析"          # 解析任务名称
    hostname1: "example.com"        # 主域名
    hostname2: "www blog shop"      # 一个或多个子域名（空格分隔）
    v4_num: 2                       # IPv4优选IP数量
    v6_num: 1                       # IPv6优选IP数量
    cf_command: "-n 500 -tll 20 -tl 300 -sl 15 -tp 2053 -t 8 -tlr 0.2"  # 测速参数
    v4_url: "https://example.com"    # IPv4地址获取
    v6_url: "https://example.com"    # IPv6地址获取
    push_mod: "Telegram"             # 推送方式
# 插件
plugin:
  clien: 不使用
# 推送
push:
- push_name: PushPlus
  pushplus_token: xxxxxxxxxxxx
github_push:
- push_name: Github
  ddns_push: www
  file_url: https://raw.githubusercontent.com/<用户名>/<私库>/refs/heads/<分支>/<文件路径>?token=<令牌>
  port: '443'
  remark: ''
  remark6: ''
```
