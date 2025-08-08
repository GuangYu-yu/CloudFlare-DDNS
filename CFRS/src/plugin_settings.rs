use anyhow::Result;
use dialoguer::{theme::ColorfulTheme, Input};
use std::path::PathBuf;
use console::Term;
use crate::{Config, Plugin};

pub struct PluginSettings {
    config_path: PathBuf,
    config: Config,
    theme: ColorfulTheme,
    term: Term,
}

impl PluginSettings {
    pub fn new(config_path: PathBuf) -> Result<Self> {
        let mut config = Config::load(&config_path)?;
        
        // 如果没有插件配置，则初始化为"不使用"
        if config.plugin.is_none() {
            config.plugin = Some(Plugin {
                clien: "不使用".to_string(),
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
            self.term.clear_screen()?;
            self.show_current_plugin()?;

            self.set_plugin()?;
        }
    }

    fn get_current_plugin(&self) -> String {
        if let Some(plugin) = &self.config.plugin {
            plugin.clien.clone()
        } else {
            "不使用".to_string()
        }
    }

    fn show_current_plugin(&self) -> Result<()> {
        let current_plugin = self.get_current_plugin();
        
        self.term.write_line(&format!("- 当前插件：{}", current_plugin))?;
        self.term.write_line("")?;
        Ok(())
    }

    fn set_plugin(&mut self) -> Result<()> {
        self.term.clear_screen()?;
        
        // 显示当前插件
        let current_plugin = self.get_current_plugin();
        
        self.term.write_line(&format!("当前插件：{}", current_plugin))?;
        self.term.write_line("")?;
        self.term.write_line("插件位于/etc/init.d/目录下，例如：passwall passwall2 shadowsocksr openclash shellcrash bypass homeproxy mihomo")?;
        self.term.write_line("")?;

        // 获取用户输入
        let input: String = Input::with_theme(&self.theme)
            .with_prompt("请输入插件名称（输入0不使用插件，留空则返回上级）")
            .allow_empty(true)
            .interact_text()?;

        if input.trim().is_empty() {
            return Ok(()); // 返回上级
        }

        let plugin_name = if input.trim() == "0" {
            "不使用".to_string()
        } else if input.chars().all(|c| c.is_ascii_alphanumeric() || c == '.' || c == '_' || c == '-') {
            input
        } else {
            self.term.write_line("插件名称格式不正确")?;
            self.term.write_line("按回车键继续...")?;
            self.term.read_line()?;
            return Ok(());
        };

        self.config.plugin = Some(Plugin {
            clien: plugin_name.clone(),
        });
        
        self.config.save(&self.config_path)?;
        self.term.write_line(&format!("插件已设置为: {}", plugin_name))?;
        self.term.write_line("按回车键继续...")?;
        self.term.read_line()?;
        Ok(())
    }
}