use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::path::PathBuf;
use colored::Colorize;

// 定义统一的错误、信息和警告输出函数
pub fn error_println(args: std::fmt::Arguments<'_>) {
    eprintln!("{} {}", "[错误]".red().bold(), args);
}

pub fn info_println(args: std::fmt::Arguments<'_>) {
    println!("{} {}", "[信息]".cyan().bold(), args);
}

pub fn warning_println(args: std::fmt::Arguments<'_>) {
    println!("{} {}", "[警告]".yellow().bold(), args);
}

// 全局常量
pub const CONFIG_FILE: &str = "cf.yaml";

// CloudflareST-Rust 全局常量，根据平台不同设置不同的值
#[cfg(target_os = "windows")]
pub const CLOUDFLAREST_RUST: &str = "CloudflareST-Rust.exe";

#[cfg(any(target_os = "linux", target_os = "macos"))]
pub const CLOUDFLAREST_RUST: &str = "CloudflareST-Rust";

// -- 账户管理 --
mod account_settings;
use account_settings::AccountSettings;

// -- 解析配置 --
mod resolve_settings;
use resolve_settings::ResolveSettings;

// -- 推送方式 --
mod push_settings;
use push_settings::PushSettings;
mod github_push_settings;

// -- 插件设置 --
mod plugin_settings;
use plugin_settings::PluginSettings;

// -- 执行解析 --
mod start;
use start::Start;

// -- 推送 --
mod push;

// -- 通用设置trait --
mod settings_trait;
use settings_trait::Settings;

// -- UI组件 --
mod ui_components;
pub use ui_components::UIComponents;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Account {
    pub account_name: String,
    pub x_email: String,
    pub zone_id: String,
    pub api_key: String,
}

#[derive(Debug, Serialize, Deserialize, Clone, PartialEq)]
pub struct Resolve {
    pub add_ddns: String,
    pub ddns_name: String,
    pub hostname1: String,
    pub hostname2: String,
    pub v4_num: u32,
    pub v6_num: u32,
    pub cf_command: String,
    pub v4_url: String,
    pub v6_url: String,
    pub push_mod: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Plugin {
    pub clien: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct PushConfig {
    pub push_name: String,
    pub telegram_bot_token: Option<String>,
    pub telegram_user_id: Option<String>,
    pub pushplus_token: Option<String>,
    pub server_sendkey: Option<String>,
    pub pushdeer_pushkey: Option<String>,
    pub wechat_corpid: Option<String>,
    pub wechat_secret: Option<String>,
    pub wechat_agentid: Option<String>,
    pub wechat_userid: Option<String>,
    pub synology_chat_url: Option<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct GithubPushConfig {
    pub ddns_push: String,
    pub file_url: String,
    pub port: String,
    pub remark: String,
    pub remark6: String,
}

#[derive(Debug, Serialize, Deserialize, Default)]
pub struct Config {
    pub account: Vec<Account>,
    pub resolve: Option<Vec<Resolve>>,
    pub plugin: Option<Plugin>,
    pub push: Option<Vec<PushConfig>>,
    pub github_push: Option<Vec<GithubPushConfig>>,
}

impl Config {
    pub fn load(path: &PathBuf) -> Result<Self> {
        if !path.exists() {
            return Ok(Config::default());
        }
        let content = fs::read_to_string(path)?;
        let config: Config = serde_yaml::from_str(&content).unwrap_or_default();
        Ok(config)
    }

    pub fn save(&self, path: &PathBuf) -> Result<()> {
        let yaml = serde_yaml::to_string(self)?;
        fs::write(path, yaml)?;
        Ok(())
    }
}

fn main() -> Result<()> {
    let mut args = env::args();

    // 处理命令行参数
    if let Some(ddns_name) = args.nth(1) {
        let config_path = PathBuf::from(CONFIG_FILE);
        let mut start = Start::new(config_path)?;
        start.run(Some(ddns_name))?;
        return Ok(());
    }

    const MENU_ITEMS: &[&str] = &["账户设置", "解析设置", "推送设置", "执行解析", "插件设置"];

    let ui = UIComponents::new();

    loop {
        clear_screen()?;
        let selection = ui.show_menu("请选择菜单项（按ESC退出）", MENU_ITEMS, 0)?;

        if let Some(selection) = selection {
            match selection {
                0 => account_settings()?,
                1 => resolve_settings()?,
                2 => push_settings()?,
                3 => execute_resolve()?,
                4 => write_plugin_settings()?,
                _ => unreachable!(),
            }
        } else {
            // 用户按ESC键退出
            std::process::exit(0);
        }
    }
}

/// 跨平台清屏函数
#[cfg(target_os = "windows")]
fn clear_screen() -> std::io::Result<()> {
    use std::process::Command;
    Command::new("cmd").args(&["/C", "cls"]).status()?;
    Ok(())
}

#[cfg(any(target_os = "linux", target_os = "macos"))]
fn clear_screen() -> std::io::Result<()> {
    use std::io::Write;
    print!("\x1Bc");
    std::io::stdout().flush()?;
    Ok(())
}

// 各个菜单项函数
fn account_settings() -> Result<()> {
    let config_path = PathBuf::from(CONFIG_FILE);
    let mut account_settings = AccountSettings::new(config_path)?;
    account_settings.run()
}

fn resolve_settings() -> Result<()> {
    let config_path = PathBuf::from(CONFIG_FILE);
    let mut resolve_settings = ResolveSettings::new(config_path)?;
    resolve_settings.run()
}

fn push_settings() -> Result<()> {
    let config_path = PathBuf::from(CONFIG_FILE);
    let mut push_settings = PushSettings::new(config_path)?;
    push_settings.run()?;
    Ok(())
}

fn execute_resolve() -> Result<()> {
    let config_path = PathBuf::from(CONFIG_FILE);
    let mut start = Start::new(config_path)?;
    start.run(None)?;
    Ok(())
}

fn write_plugin_settings() -> Result<()> {
    let config_path = PathBuf::from(CONFIG_FILE);
    let mut plugin_settings = PluginSettings::new(config_path)?;
    plugin_settings.run()
}