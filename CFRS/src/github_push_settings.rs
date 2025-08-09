use anyhow::Result;
use dialoguer::{theme::ColorfulTheme, Select, Input};
use std::path::PathBuf;
use console::Term;
use regex::Regex;
use crate::{Config, GithubPushConfig, clear_screen};

pub struct GithubPushSettings {
    config_path: PathBuf,
    config: Config,
    theme: ColorfulTheme,
    term: Term,
}

impl GithubPushSettings {
    pub fn new(config_path: PathBuf) -> Result<Self> {
        Ok(GithubPushSettings {
            config: Config::load(&config_path)?,
            config_path,
            theme: ColorfulTheme::default(),
            term: Term::stdout(),
        })
    }

    pub fn run(&mut self) -> Result<()> {
        loop {
            clear_screen()?;
            
            // 显示当前的 Github 推送配置
            self.term.write_line("当前配置：")?;
            if let Some(github_configs) = &self.config.github_push {
                let config_str = github_configs.iter().map(|config| {
                    format!("解析组：{}\n文件URL：{}\n端口：{}\nIPv4备注：{}\nIPv6备注：{}\n", 
                        config.ddns_push, config.file_url, config.port, config.remark, config.remark6)
                }).collect::<Vec<_>>().join("");
                self.term.write_line(&config_str)?;
            } else {
                self.term.write_line("暂无配置")?;
            }

            let items = [
                "添加条目",
                "删除条目",
            ];

            let selection = Select::with_theme(&self.theme)
                .with_prompt("Github 推送设置（按ESC返回上级）")
                .items(&items)
                .default(0)
                .interact_opt()?;

            // 如果用户按ESC返回，则直接返回
            let selection = match selection {
                Some(value) => value,
                None => return Ok(()),
            };

            match selection {
                0 => self.add_github_push()?,
                1 => self.delete_github_push()?,
                _ => unreachable!(),
            }
        }
    }

fn add_github_push(&mut self) -> Result<()> {
    self.term.write_line("添加 Github 推送")?;

    // 检查是否有解析组
    let resolves = match &self.config.resolve {
        Some(r) if !r.is_empty() => r,
        _ => {
            self.term.write_line("当前还没添加解析组")?;
            self.term.read_line()?; // 等待用户按下回车
            return Ok(());
        }
    };
    clear_screen()?;

    // 创建解析组选择项
    let resolve_names: Vec<&String> = resolves.iter().map(|r| &r.ddns_name).collect();
    
    // 使用Select让用户选择解析组
    let selection = Select::with_theme(&self.theme)
        .with_prompt("请选择解析组（按ESC返回上级）")
        .items(&resolve_names)
        .default(0)
        .interact_opt()?;

    // 如果用户按ESC返回，则直接返回
    let selection = match selection {
        Some(value) => value,
        None => return Ok(()),
    };

    // 获取选中的解析组名称
    let ddns_push = resolves[selection].ddns_name.clone();

        let file_url: String = loop {
            let input: String = Input::with_theme(&self.theme)
                .with_prompt("请输入文件URL")
                .interact_text()?;

            // 使用正则表达式验证URL格式
            if Regex::new(r"^https?://")?.is_match(&input) {
                break input;
            }
            
            self.term.write_line("URL格式不正确")?;
            self.term.read_line()?;
        };

        let port = loop {
            let input: String = Input::with_theme(&self.theme)
                .with_prompt("请输入端口")
                .interact_text()?;

            if Regex::new(r"^[0-9]+$")?.is_match(&input) {
                break input;
            }
            
            self.term.write_line("端口必须是数字")?;
            self.term.read_line()?;
        };

        let remark: String = Input::with_theme(&self.theme)
            .with_prompt("请输入IPv4备注（留空则不设置）")
            .allow_empty(true)
            .interact_text()?;

        let remark6: String = Input::with_theme(&self.theme)
            .with_prompt("请输入IPv6备注（留空则不设置）")
            .allow_empty(true)
            .interact_text()?;

        // 创建新的配置
        let new_config = GithubPushConfig {
            ddns_push,
            file_url,
            port,
            remark,
            remark6,
        };

        // 添加配置
        if let Some(github_configs) = &mut self.config.github_push {
            github_configs.push(new_config);
        } else {
            self.config.github_push = Some(vec![new_config]);
        }

        self.config.save(&self.config_path)?;
        self.term.write_line("Github 推送配置已添加！")?;
        self.term.read_line()?;
        Ok(())
    }

    fn delete_github_push(&mut self) -> Result<()> {
        self.term.write_line("删除 Github 推送")?;

        // 收集所有 Github 推送配置
        let github_configs = if let Some(configs) = &self.config.github_push {
            configs.clone()
        } else {
            Vec::new()
        };
        clear_screen()?;

        if github_configs.is_empty() {
            self.term.write_line("暂无配置")?;
            self.term.read_line()?;
            return Ok(());
        }

        // 创建显示项
        let display_items: Vec<String> = github_configs.iter().map(|config| {
            format!("解析组：{} | 文件URL：{} | 端口：{} | IPv4备注：{} | IPv6备注：{}", 
                config.ddns_push, 
                config.file_url, 
                config.port, 
                &config.remark, 
                &config.remark6)
        }).collect();

        let selection = Select::with_theme(&self.theme)
            .with_prompt("请选择要删除的推送条目（按ESC返回上级）")
            .items(&display_items)
            .default(0)
            .interact_opt()?;

        // 如果用户选择空（按下ESC或通过其他方式返回），则直接返回
        let selection = match selection {
            Some(value) => value,
            None => return Ok(()),
        };

        // 确认删除
        let config_to_delete = &github_configs[selection];
        let confirm = Select::with_theme(&self.theme)
            .with_prompt(&format!("确认删除解析组 {} 的推送配置吗？（按ESC返回上级）", config_to_delete.ddns_push))
            .items(&["是", "否"])
            .default(1)
            .interact_opt()?;

        // 如果用户按ESC返回，则直接返回
        let confirm = match confirm {
            Some(value) => value,
            None => return Ok(()),
        };

        if confirm == 0 {
            if let Some(github_configs) = &mut self.config.github_push {
                // 删除匹配的配置（基于所有字段完全匹配）
                github_configs.retain(|c| {
                    !(c.ddns_push == config_to_delete.ddns_push
                      && c.file_url == config_to_delete.file_url
                      && c.port == config_to_delete.port
                      && c.remark == config_to_delete.remark
                      && c.remark6 == config_to_delete.remark6)
                });
                
                self.config.save(&self.config_path)?;
                self.term.write_line("Github 推送配置已删除！")?;
            }
        } else {
            self.term.write_line("取消删除操作")?;
        }

        self.term.read_line()?;
        Ok(())
    }
}