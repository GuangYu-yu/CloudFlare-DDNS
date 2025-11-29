use crate::ui_components::UIComponents;
use crate::{Config, GithubPushConfig, Settings, clear_screen, impl_settings};
use anyhow::Result;
use std::path::{Path, PathBuf};

pub struct GithubPushSettings {
    config_path: PathBuf,
    config: Config,
    ui: UIComponents,
}

impl GithubPushSettings {
    pub fn new(config_path: &Path) -> Result<Self> {
        let mut settings = GithubPushSettings {
            config: Config::default(),
            config_path: config_path.to_path_buf(),
            ui: UIComponents::new(),
        };
        settings.load_config()?;
        Ok(settings)
    }

    pub fn run(&mut self) -> Result<()> {
        loop {
            clear_screen()?;

            // 显示当前的 Github 推送配置
            self.ui.show_message("当前配置：")?;
            if let Some(github_configs) = &self.config.github_push {
                let config_str = github_configs
                    .iter()
                    .map(|config| {
                        format!(
                            "解析组：{}\n文件URL：{}\n端口：{}\nIPv4备注：{}\nIPv6备注：{}\n",
                            config.ddns_push,
                            config.file_url,
                            config.port,
                            config.remark,
                            config.remark6
                        )
                    })
                    .collect::<Vec<_>>()
                    .join("\n"); // 使用换行符分隔不同的配置
                self.ui.show_message(&config_str)?;
            } else {
                self.ui.show_message("暂无配置")?;
            }

            let items = ["添加条目", "删除条目"];

            let selection = self
                .ui
                .show_menu("Github 推送设置（按ESC返回上级）", &items, 0)?;

            match selection {
                Some(0) => self.add_github_push()?,
                Some(1) => self.delete_github_push()?,
                None => return Ok(()),
                _ => unreachable!(),
            }
        }
    }

    fn add_github_push(&mut self) -> Result<()> {
        self.ui.show_message("添加 Github 推送")?;

        // 检查是否有解析组
        let resolves = match &self.config.resolve {
            Some(r) if !r.is_empty() => r,
            _ => {
                self.ui.show_message("当前还没添加解析组")?;
                self.ui.pause("")?;
                return Ok(());
            }
        };
        clear_screen()?;

        // 创建解析组选择项
        let resolve_names: Vec<&str> = resolves.iter().map(|r| r.ddns_name.as_str()).collect();

        // 使用Select让用户选择解析组
        let selection = self
            .ui
            .show_menu("请选择解析组（按ESC返回上级）", &resolve_names, 0)?;

        // 如果用户按ESC返回，则直接返回
        let selection = match selection {
            Some(value) => value,
            None => return Ok(()),
        };

        // 获取选中的解析组名称
        let ddns_push = resolves[selection].ddns_name.clone();

        let file_url = self.ui.get_url_input("请输入文件URL", false)?;

        let port = self.ui.get_text_input("请输入端口", "", |input| {
            // 验证端口是否为数字
            if input.is_empty() {
                return false;
            }
            input.chars().all(|c| c.is_ascii_digit())
        })?;

        // 循环获取备注，直到至少设置一项
        let (remark, remark6) = loop {
            let remark = self
                .ui
                .get_text_input_simple("请输入IPv4备注（留空则不设置）", "")?;

            let remark6 = self
                .ui
                .get_text_input_simple("请输入IPv6备注（留空则不设置）", "")?;

            // 验证至少设置一项备注
            if remark.is_empty() && remark6.is_empty() {
                self.ui.show_error("必须设置其中一项备注（IPv4或IPv6）")?;
                // 继续循环，重新输入
                continue;
            } else {
                break (remark, remark6);
            }
        };

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

        self.config.save(self.config_path.as_path())?;
        self.ui.show_success("Github 推送配置已添加！")?;
        Ok(())
    }

    fn delete_github_push(&mut self) -> Result<()> {
        self.ui.show_message("删除 Github 推送")?;

        // 检查是否有 Github 推送配置
        if self.config.github_push.is_none() || self.config.github_push.as_ref().unwrap().is_empty()
        {
            self.ui.show_message("暂无配置")?;
            self.ui.pause("")?;
            return Ok(());
        }

        clear_screen()?;

        // 创建显示项
        let display_items: Vec<String> = self
            .config
            .github_push
            .as_ref()
            .unwrap()
            .iter()
            .map(|config| {
                format!(
                    "解析组：{} | 文件URL：{} | 端口：{} | IPv4备注：{} | IPv6备注：{}",
                    config.ddns_push, config.file_url, config.port, config.remark, config.remark6
                )
            })
            .collect();

        let display_items_refs: Vec<&str> = display_items.iter().map(|s| s.as_str()).collect();

        let selection = self.ui.show_menu(
            "请选择要删除的推送条目（按ESC返回上级）",
            &display_items_refs,
            0,
        )?;

        // 如果用户选择空（按下ESC或通过其他方式返回），则直接返回
        let selection = match selection {
            Some(value) => value,
            None => return Ok(()),
        };

        // 确认删除
        let selection_index = selection;
        let confirm_msg = format!(
            "确认删除解析组 {} 的推送配置吗？（按ESC返回上级）",
            self.config.github_push.as_ref().unwrap()[selection_index].ddns_push
        );

        let confirm = self.ui.show_menu(&confirm_msg, &["是", "否"], 1)?;

        // 如果用户按ESC返回，则直接返回
        let confirm = match confirm {
            Some(value) => value,
            None => return Ok(()),
        };

        if confirm == 0 {
            if let Some(github_configs) = &mut self.config.github_push {
                // 直接使用索引删除配置
                github_configs.remove(selection_index);

                self.config.save(self.config_path.as_path())?;
                self.ui.show_success("Github 推送配置已删除！")?;
            }
        } else {
            self.ui.show_message("取消删除操作")?;
        }

        Ok(())
    }
}

impl_settings!(GithubPushSettings);