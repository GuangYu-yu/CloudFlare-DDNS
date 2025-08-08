# 🚀 OPW-Cloudflare

<p align="center">
  <img src="https://img.shields.io/badge/Platform-OpenWrt%20%7C%20Linux-blue.svg" alt="Platform">
  <img src="https://img.shields.io/badge/Language-Bash%20%7C%20Shell-blue.svg" alt="Language">
  <a href="https://github.com/GuangYu-yu/opw-cloudflare">
    <img src="https://img.shields.io/github/stars/GuangYu-yu/opw-cloudflare?style=social" alt="GitHub Stars">
  </a>
  <a href="https://deepwiki.com/GuangYu-yu/opw-cloudflare">
    <img src="https://deepwiki.com/badge.svg" alt="Ask DeepWiki">
  </a>
</p>

## 📖 项目简介

**OPW-Cloudflare** 主要用于在OpenWrt优选IP，通过集成[CloudflareST-Rust](https://github.com/GuangYu-yu/CloudflareST-Rust)实现Cloudflare IP地址的自动测速与优选，并将最优IP自动更新到Cloudflare DNS记录。

## ✨ 功能特性

| 功能类别 | 具体特性 |
|---------|---------|
| 🌐 **IP优选** | • 自动测速Cloudflare全球节点<br>• 支持IPv4/IPv6优选<br>• 自定义测速参数 |
| 🔄 **DNS管理** | • 自动更新Cloudflare DNS记录<br>• 支持多个域名和子域名<br>• 批量解析管理 |
| 📱 **消息推送** | • 多种推送途径<br>• 自定义推送内容 |
| 📊 **数据管理** | • 测速结果本地存储<br>• 支持GitHub提交（需要令牌）<br> |
| ⚙️ **灵活配置** | • YAML配置文件<br>• 多账户支持<br>• 定时任务集成 |

### 🔧 安装方式

#### 方式一：GitHub API安装
```bash
# 需要安装 jq 和 base64
curl -s "https://api.github.com/repos/GuangYu-yu/opw-cloudflare/contents/cfopw.sh" | jq -r '.content' | base64 -d | bash
```

#### 方式二：GitHub Raw安装
```bash
curl -ksSL https://raw.githubusercontent.com/GuangYu-yu/opw-cloudflare/main/cfopw.sh | bash
```

#### 方式三：镜像源安装
```bash
curl -ksSL https://ghproxy.cc/https://raw.githubusercontent.com/GuangYu-yu/opw-cloudflare/main/cfopw.sh | bash
```

### 🎯 首次运行

安装完成后，通过主菜单进行配置：
```bash
bash cf
```

## ⚙️ 配置文件详解

### 📄 配置文件结构 (`cf.yaml`)

```yaml
# 账户信息配置
account:
  - account_name: "主账户"           # 账户标识名称
    x_email: "your@email.com"        # Cloudflare注册邮箱
    zone_id: "your_zone_id"          # 域名对应的Zone ID
    api_key: "your_api_key"          # Cloudflare API密钥

# DNS解析配置
resolve:
  - add_ddns: "主账户"              # 关联的账户名称
    ddns_name: "主域名解析"          # 解析任务名称
    hostname1: "example.com"        # 主域名
    hostname2: "www blog shop"      # 子域名列表（空格分隔）
    v4_num: 2                       # IPv4优选IP数量
    v6_num: 1                       # IPv6优选IP数量
    cf_command: "-n 500 -tll 20 -tl 300 -sl 15 -tp 2053 -t 8 -tlr 0.2"  # 测速参数
    v4_url: "https://ipv4.icanhazip.com"    # IPv4地址获取接口
    v6_url: "https://ipv6.icanhazip.com"    # IPv6地址获取接口
    push_mod: "Telegram"             # 推送方式
```

### 🔑 参数说明

| 参数 | 说明 | 示例 |
|-----|------|------|
| `account_name` | 账户标识，可自定义 | `"主域名"` |
| `x_email` | Cloudflare账户邮箱 | `"admin@example.com"` |
| `zone_id` | 域名Zone ID | `"a1b2c3d4e5f6"` |
| `api_key` | Cloudflare Global API Key | `"xxxxxxxxxxxxxxxx"` |
| `hostname1` | 需要解析的主域名 | `"example.com"` |
| `hostname2` | 子域名列表（空格分隔） | `"www blog api"` |
| `v4_num/v6_num` | 优选IP数量 | `2` |

## 📁 项目结构

```
opw-cloudflare/
├── 📄 README.md                    # 项目说明文档
├── 🖥️  cf                          # 主菜单脚本（核心）
├── 📤 cf_push.sh                  # 消息推送服务
├── 🚀 cfopw.sh                    # 初始安装脚本
├── ⚙️  eg.yaml                     # 配置文件模板
├── 🔄 setup_cloudflarest.sh       # CloudflareST-Rust更新工具
├── 🎯 start_ddns.sh               # 测速与DNS更新主程序
├── 📁 .github/workflows/          # GitHub Actions工作流
│   └── build.yml                  # 自动化构建配置
└── 🗂️  old_cf.sh                  # 旧版本兼容脚本
```

## 🎯 使用指南

### 📋 基本操作步骤

   **首次配置**
   ```bash
   # 运行主菜单
   bash cf
   
   # 选择配置向导
   [1] 配置账户信息
   [2] 配置解析
   [3] 配置推送服务
   [4] 暂停插件功能
   [5] 配置计划任务
   ```

   **直接执行**
   ```bash
   bash cf start www
   ```
