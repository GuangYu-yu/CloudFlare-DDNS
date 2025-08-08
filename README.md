# 🚀 CloudFlare-DDNS

<p align="center">
  <img src="https://img.shields.io/badge/Platform-OpenWrt%20%7C%20Linux-blue.svg" alt="Platform">
  <img src="https://img.shields.io/badge/Language-Bash%20%7C%20Shell-blue.svg" alt="Language">
  <a href="https://github.com/GuangYu-yu/CloudFlare-DDNS">
    <img src="https://img.shields.io/github/stars/GuangYu-yu/CloudFlare-DDNS?style=social" alt="GitHub Stars">
  </a>
  <a href="https://deepwiki.com/GuangYu-yu/CloudFlare-DDNS">
    <img src="https://deepwiki.com/badge.svg" alt="Ask DeepWiki">
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
| ⚙️ **灵活配置** | • YAML配置文件<br>• 多账户支持<br>• 可直接传入解析组来执行<br> |

### 🔧 安装方式


#### GitHub
```bash
curl -ksSL https://raw.githubusercontent.com/GuangYu-yu/CloudFlare-DDNS/main/setup/cfopw.sh | bash
```

#### 镜像源
```bash
curl -ksSL https://ghproxy.cc/https://raw.githubusercontent.com/GuangYu-yu/CloudFlare-DDNS/main/setup/cfopw.sh | bash
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
    hostname2: "www blog shop"      # 子域名列表（空格分隔）
    v4_num: 2                       # IPv4优选IP数量
    v6_num: 1                       # IPv6优选IP数量
    cf_command: "-n 500 -tll 20 -tl 300 -sl 15 -tp 2053 -t 8 -tlr 0.2"  # 测速参数
    v4_url: "https://ipv4.icanhazip.com"    # IPv4地址获取接口
    v6_url: "https://ipv6.icanhazip.com"    # IPv6地址获取接口
    push_mod: "Telegram"             # 推送方式
```
