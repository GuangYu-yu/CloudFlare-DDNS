use anyhow::Result;
use dialoguer::{theme::ColorfulTheme, Input};
use std::path::PathBuf;
use console::Term;
use crate::{Config, Plugin, clear_screen};

pub struct PluginSettings {
    config_path: PathBuf,
    config: Config,
    theme: ColorfulTheme,
    term: Term,
}

impl PluginSettings {
    pub fn new(config_path: PathBuf) -> Result<Self> {
        let mut config = Config::load(&config_path)?;
        
        // 如果没有插件配置，则初始化为"未指定"
        if config.plugin.is_none() {
            config.plugin = Some(Plugin {
                clien: "未指定".to_string(),
            });
        }
        
        Ok(PluginSettings {
            config,
            config_path,
            theme: ColorfulTheme::default(),
            term: Term::stdout(),
        })
    }

    pub fn run(&mut self) -> Result<()> {
        loop {
            clear_screen()?;

            if !self.set_plugin()? {
                break;
            }
        }
        Ok(())
    }

    fn get_current_plugin(&self) -> String {
        self.config.plugin.as_ref()
            .map(|p| p.clien.clone())
            .unwrap_or_else(|| "未指定".to_string())
    }

    fn set_plugin(&mut self) -> Result<bool> {
        clear_screen()?;
        
        // 显示当前插件
        let current_plugin = self.get_current_plugin();
        
        self.term.write_line(&format!("测速前暂停指定插件，当前插件：{}", current_plugin))?;
        self.term.write_line("")?;
        self.term.write_line("插件位于/etc/init.d/目录下，例如：passwall passwall2 shadowsocksr openclash shellcrash bypass homeproxy mihomo")?;
        self.term.write_line("")?;

        // 获取用户输入
        let input: String = Input::with_theme(&self.theme)
            .with_prompt("请输入插件名称（输入 0 不指定插件，留空则返回上级）")
            .allow_empty(true)
            .interact_text()?;

        if input.trim().is_empty() {
            return Ok(false); // 返回上级
        }

        let plugin_name = if input.trim() == "0" {
            "未指定".to_string()
        } else if input.chars().all(|c| c.is_ascii_alphanumeric() || c == '.' || c == '_' || c == '-') {
            input
        } else {
            self.term.write_line("插件名称格式不正确")?;
            self.term.write_line("按回车键继续...")?;
            self.term.read_line()?;
            return Ok(true);
        };

        self.config.plugin = Some(Plugin {
            clien: plugin_name.clone(),
        });
        
        self.config.save(&self.config_path)?;
        self.term.write_line(&format!("插件已设置为: {}", plugin_name))?;
        self.term.write_line("按回车键继续...")?;
        self.term.read_line()?;
        Ok(true)
    }
}