use crate::ui_components::UIComponents;
use crate::{Config, PushConfig, Settings, clear_screen, impl_settings};
use anyhow::Result;
use std::path::PathBuf;

pub struct PushSettings {
    config_path: PathBuf,
    config: Config,
    ui: UIComponents,
}

impl PushSettings {
    pub fn new(config_path: PathBuf) -> Result<Self> {
        let mut settings = PushSettings {
            config_path: config_path.clone(),
            config: Config::default(),
            ui: UIComponents::new(),
        };
        settings.load_config()?;
        Ok(settings)
    }

    pub fn run(&mut self) -> Result<()> {
        loop {
            clear_screen()?;
            self.list_push_configs()?;

            let items = [
                "Telegram",
                "PushPlus",
                "Server酱",
                "PushDeer",
                "企业微信",
                "Synology-Chat",
                "提交到Github",
            ];

            let selection = self.ui.show_menu("推送管理（按ESC返回上级）", &items, 0)?;

            match selection {
                Some(idx) => {
                    if idx < items.len() - 1 { // 减1因为最后一个是"提交到Github"
                        self.manage_push(items[idx])?;
                    } else if idx == items.len() - 1 {
                        // 调用 GitHub 推送设置
                        self.manage_github_push()?;
                    }
                }
                None => return Ok(()),
            }
        }
    }

    fn list_push_configs(&self) -> Result<()> {
        if let Some(push_configs) = &self.config.push {
            let push_info = push_configs
                .iter()
                .map(|config| {
                    let mut info = format!("- 推送类型: {}\n", config.push_name);
                    match config.push_name.as_str() {
                        "Telegram" => {
                            if let Some(token) = &config.telegram_bot_token {
                                info.push_str(&format!("  Bot Token: {}\n", token));
                            }
                            if let Some(user_id) = &config.telegram_user_id {
                                info.push_str(&format!("  User ID: {}\n", user_id));
                            }
                        }
                        "PushPlus" => {
                            if let Some(token) = &config.pushplus_token {
                                info.push_str(&format!("  Token: {}\n", token));
                            }
                        }
                        "Server酱" => {
                            if let Some(sendkey) = &config.server_sendkey {
                                info.push_str(&format!("  SendKey: {}\n", sendkey));
                            }
                        }
                        "PushDeer" => {
                            if let Some(pushkey) = &config.pushdeer_pushkey {
                                info.push_str(&format!("  PushKey: {}\n", pushkey));
                            }
                        }
                        "企业微信" => {
                            if let Some(corpid) = &config.wechat_corpid {
                                info.push_str(&format!("  企业ID: {}\n", corpid));
                            }
                            if let Some(secret) = &config.wechat_secret {
                                info.push_str(&format!("  应用Secret: {}\n", secret));
                            }
                            if let Some(agentid) = &config.wechat_agentid {
                                info.push_str(&format!("  应用ID: {}\n", agentid));
                            }
                            if let Some(userid) = &config.wechat_userid {
                                info.push_str(&format!("  接收者ID: {}\n", userid));
                            }
                        }
                        "Synology-Chat" => {
                            if let Some(url) = &config.synology_chat_url {
                                info.push_str(&format!("  Webhook URL: {}\n", url));
                            }
                        }
                        _ => {}
                    }
                    info
                })
                .collect::<Vec<String>>();

            self.ui.show_info_list("", &push_info)?;
        } else {
            self.ui.show_message("当前没有设置任何推送配置")?;
            self.ui.show_message("")?;
        }
        Ok(())
    }

    fn manage_github_push(&mut self) -> Result<()> {
        let mut github_push_settings =
            crate::github_push_settings::GithubPushSettings::new(self.config_path.clone())?;
        github_push_settings.run()
    }

    fn manage_push(&mut self, push_name: &str) -> Result<()> {
        loop {
            clear_screen()?;
            self.ui.show_message(&format!("{} 推送管理", push_name))?;

            // 显示当前设置
            let current_config = self
                .config
                .push
                .as_ref()
                .and_then(|configs| configs.iter().find(|c| c.push_name == push_name));

            if let Some(config) = current_config {
                self.ui.show_message("当前设置：")?;
                match push_name {
                    "Telegram" => {
                        if let Some(token) = &config.telegram_bot_token {
                            self.ui.show_message(&format!("Bot Token：{}", token))?;
                        }
                        if let Some(user_id) = &config.telegram_user_id {
                            self.ui.show_message(&format!("User ID：{}", user_id))?;
                        }
                    }
                    "PushPlus" => {
                        if let Some(token) = &config.pushplus_token {
                            self.ui.show_message(&format!("Token：{}", token))?;
                        }
                    }
                    "Server酱" => {
                        if let Some(sendkey) = &config.server_sendkey {
                            self.ui.show_message(&format!("SendKey：{}", sendkey))?;
                        }
                    }
                    "PushDeer" => {
                        if let Some(pushkey) = &config.pushdeer_pushkey {
                            self.ui.show_message(&format!("PushKey：{}", pushkey))?;
                        }
                    }
                    "企业微信" => {
                        if let Some(corpid) = &config.wechat_corpid {
                            self.ui.show_message(&format!("企业ID：{}", corpid))?;
                        }
                        if let Some(secret) = &config.wechat_secret {
                            self.ui.show_message(&format!("应用Secret：{}", secret))?;
                        }
                        if let Some(agentid) = &config.wechat_agentid {
                            self.ui.show_message(&format!("应用ID：{}", agentid))?;
                        }
                        if let Some(userid) = &config.wechat_userid {
                            self.ui.show_message(&format!("接收者ID：{}", userid))?;
                        }
                    }
                    "Synology-Chat" => {
                        if let Some(url) = &config.synology_chat_url {
                            self.ui.show_message(&format!("Webhook URL：{}", url))?;
                        }
                    }
                    _ => {}
                }
            } else {
                self.ui.show_message("当前没有设置任何参数")?;
            }

            let items = ["设置/修改参数", "删除推送"];

            let selection = self
                .ui
                .show_menu("请选择操作（按ESC返回上级）", &items, 0)?;

            match selection {
                Some(0) => {
                    if current_config.is_some() {
                        self.configure_push(push_name, true)?;
                    } else {
                        self.configure_push(push_name, false)?;
                    }
                }
                Some(1) => {
                    if current_config.is_some() {
                        self.delete_push(push_name)?;
                    } else {
                        self.ui.show_message(&format!("{} 未设置", push_name))?;
                        self.ui.pause("")?;
                    }
                }
                None => break,
                _ => {}
            }
        }
        Ok(())
    }

    fn configure_push(&mut self, push_name: &str, is_modify: bool) -> Result<()> {
        if is_modify {
            self.ui
                .show_message(&format!("正在修改 {} 推送...", push_name))?;
        } else {
            self.ui
                .show_message(&format!("正在设置 {} 推送...", push_name))?;
        }

        let mut new_config = PushConfig {
            push_name: push_name.to_string(),
            telegram_bot_token: None,
            telegram_user_id: None,
            pushplus_token: None,
            server_sendkey: None,
            pushdeer_pushkey: None,
            wechat_corpid: None,
            wechat_secret: None,
            wechat_agentid: None,
            wechat_userid: None,
            synology_chat_url: None,
        };

        match push_name {
            "Telegram" => {
                let token = self
                    .ui
                    .get_non_empty_input("请输入 telegram_bot_token", "")?;
                new_config.telegram_bot_token = Some(token);

                let user_id = self.ui.get_non_empty_input("请输入 telegram_user_id", "")?;
                new_config.telegram_user_id = Some(user_id);
            }
            "PushPlus" => {
                let token = self.ui.get_non_empty_input("请输入 pushplus_token", "")?;
                new_config.pushplus_token = Some(token);
            }
            "Server酱" => {
                let sendkey = self.ui.get_non_empty_input("请输入 server_sendkey", "")?;
                new_config.server_sendkey = Some(sendkey);
            }
            "PushDeer" => {
                let pushkey = self.ui.get_non_empty_input("请输入 pushdeer_pushkey", "")?;
                new_config.pushdeer_pushkey = Some(pushkey);
            }
            "企业微信" => {
                let corpid = self
                    .ui
                    .get_non_empty_input("请输入 企业ID (wechat_corpid)", "")?;
                new_config.wechat_corpid = Some(corpid);

                let secret = self
                    .ui
                    .get_non_empty_input("请输入 应用Secret (wechat_secret)", "")?;
                new_config.wechat_secret = Some(secret);

                let agentid = self
                    .ui
                    .get_non_empty_input("请输入 应用ID (wechat_agentid)", "")?;
                new_config.wechat_agentid = Some(agentid);

                let userid = self
                    .ui
                    .get_non_empty_input("请输入 接收者ID (wechat_userid)", "")?;
                new_config.wechat_userid = Some(userid);
            }
            "Synology-Chat" => {
                let url = self
                    .ui
                    .get_url_input("请输入 Webhook URL (synology_chat_url)", false)?;
                new_config.synology_chat_url = Some(url);
            }
            _ => {}
        }

        // 保存配置
        if let Some(push_configs) = &mut self.config.push {
            if is_modify {
                // 更新现有配置
                if let Some(pos) = push_configs.iter().position(|c| c.push_name == push_name) {
                    push_configs[pos] = new_config;
                }
            } else {
                // 添加新配置
                push_configs.push(new_config);
            }
        } else {
            // 创建新的推送配置向量
            self.config.push = Some(vec![new_config]);
        }

        self.config.save(&self.config_path)?;
        self.ui
            .show_success(&format!("{} 参数已设置完成！", push_name))?;
        Ok(())
    }

    fn delete_push(&mut self, push_name: &str) -> Result<()> {
        let items = ["是", "否"];
        let selection =
            self.ui
                .show_menu(&format!("确认删除 {} 的推送设置吗？", push_name), &items, 1)?;

        match selection {
            Some(0) => {
                if let Some(push_configs) = &mut self.config.push {
                    push_configs.retain(|c| c.push_name != push_name);

                    // 如果没有剩余的推送设置，删除 push 键
                    if push_configs.is_empty() {
                        self.config.push = None;
                    }

                    self.config.save(&self.config_path)?;
                    self.ui
                        .show_success(&format!("{} 的推送设置已删除", push_name))?;
                }
            }
            Some(1) => {
                self.ui.show_message("取消删除操作")?;
                self.ui.pause("")?;
            }
            None => return Ok(()),
            _ => {}
        }
        Ok(())
    }
}

impl_settings!(PushSettings);