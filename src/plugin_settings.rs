use crate::ui_components::UIComponents;
use crate::{Config, Plugin, Settings, clear_screen, impl_settings};
use anyhow::Result;
use std::path::{Path, PathBuf};

pub struct PluginSettings {
    config_path: PathBuf,
    config: Config,
    ui: UIComponents,
}

impl PluginSettings {
    pub fn new(config_path: &Path) -> Result<Self> {
        let mut settings = PluginSettings {
            config_path: config_path.to_path_buf(),
            config: Config::default(),
            ui: UIComponents::new(),
        };
        settings.load_config()?;

        // 如果没有插件配置，则初始化为"未指定"
        if settings.config.plugin.is_none() {
            settings.config.plugin = Some(Plugin {
                clien: "未指定".to_string(),
            });
        }

        Ok(settings)
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

    fn get_current_plugin(&self) -> &str {
        self.config
            .plugin
            .as_ref()
            .map_or_else(|| "未指定", |p| &p.clien)
    }

    fn set_plugin(&mut self) -> Result<bool> {
        clear_screen()?;

        // 定义允许的插件名称白名单
        let allowed_plugins = [
            "passwall",
            "passwall2",
            "shadowsocksr",
            "clash",
            "openclash",
            "bypass",
            "v2raya",
            "vssr",
            "homeproxy",
            "nikki",
            "shellcrash",
            "mihomo",
        ];

        // 显示当前插件
        let current_plugin = self.get_current_plugin();

        self.ui
            .show_message(&format!("测速前暂停指定插件，当前插件：{}", current_plugin))?;
        self.ui.show_message("")?;
        self.ui
            .show_message("插件位于/etc/init.d/目录下，白名单列表：")?;

        // 使用allowed_plugins数组生成插件列表字符串
        let plugin_list = allowed_plugins.join(" ");
        self.ui.show_message(&plugin_list)?;
        self.ui.show_message("")?;

        // 获取用户输入
        let input = self.ui.get_text_input(
            "请输入插件名称（输入 0 不指定插件，留空则返回上级）",
            "",
            |input| {
                // 允许空输入（返回上级）
                if input.trim().is_empty() {
                    return true;
                }
                // 允许输入"0"（不指定插件）
                if input.trim() == "0" {
                    return true;
                }
                // 验证插件名称格式
                input
                    .chars()
                    .all(|c| c.is_ascii_alphanumeric() || c == '.' || c == '_' || c == '-')
            },
        )?;

        if input.trim().is_empty() {
            return Ok(false); // 返回上级
        }

        let plugin_name = if input.trim() == "0" {
            "未指定".to_string()
        } else {
            let trimmed_input = input.trim();

            // 检查是否在白名单中
            if allowed_plugins.contains(&trimmed_input) {
                trimmed_input.to_string()
            } else {
                let confirm = self.ui.get_text_input(
                    &format!(
                        "确认使用插件 '{}'？输入 'yes' 确认（不区分大小写），其他输入取消",
                        trimmed_input
                    ),
                    "",
                    |_| true,
                )?;

                if confirm.trim().to_lowercase() == "yes" {
                    trimmed_input.to_string()
                } else {
                    return Ok(false); // 返回上级
                }
            }
        };

        self.config.plugin = Some(Plugin {
            clien: plugin_name.clone(),
        });

        self.config.save(self.config_path.as_path())?;
        self.ui
            .show_success(&format!("插件已设置为: {}", plugin_name))?;
        Ok(true)
    }
}

impl_settings!(PluginSettings);