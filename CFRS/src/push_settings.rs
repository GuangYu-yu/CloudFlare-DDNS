use anyhow::Result;
use dialoguer::{theme::ColorfulTheme, Select, Input};
use std::path::PathBuf;
use console::Term;
use crate::{Config, PushConfig};

pub struct PushSettings {
    config_path: PathBuf,
    config: Config,
    theme: ColorfulTheme,
    term: Term,
}

impl PushSettings {
    pub fn new(config_path: PathBuf) -> Result<Self> {
        Ok(PushSettings {
            config: Config::load(&config_path)?,
            config_path,
            theme: ColorfulTheme::default(),
            term: Term::stdout(),
        })
    }

    pub fn run(&mut self) -> Result<()> {
        loop {
            self.term.clear_screen()?;
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

            let selection = Select::with_theme(&self.theme)
                .with_prompt("推送管理（按ESC返回上级）")
                .items(&items)
                .default(0)
                .interact_opt()?;

            // 如果用户按ESC返回，则直接返回
            let selection = match selection {
                Some(value) => value,
                None => return Ok(()),
            };

            match selection {
                0 => self.manage_push("Telegram")?,
                1 => self.manage_push("PushPlus")?,
                2 => self.manage_push("Server酱")?,
                3 => self.manage_push("PushDeer")?,
                4 => self.manage_push("企业微信")?,
                5 => self.manage_push("Synology-Chat")?,
                6 => {
                    // 调用 GitHub 推送设置
                    self.manage_github_push()?;
                },
                _ => unreachable!(),
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
                        },
                        "PushPlus" => {
                            if let Some(token) = &config.pushplus_token {
                                info.push_str(&format!("  Token: {}\n", token));
                            }
                        },
                        "Server酱" => {
                            if let Some(sendkey) = &config.server_sendkey {
                                info.push_str(&format!("  SendKey: {}\n", sendkey));
                            }
                        },
                        "PushDeer" => {
                            if let Some(pushkey) = &config.pushdeer_pushkey {
                                info.push_str(&format!("  PushKey: {}\n", pushkey));
                            }
                        },
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
                        },
                        "Synology-Chat" => {
                            if let Some(url) = &config.synology_chat_url {
                                info.push_str(&format!("  Webhook URL: {}\n", url));
                            }
                        },
                        _ => {}
                    }
                    info.push_str("\n");
                    info
                })
                .collect::<Vec<String>>()
                .join("");
            self.term.write_line(&push_info)?;
        } else {
            self.term.write_line("当前没有设置任何推送配置")?;
            self.term.write_line("")?;
        }
        Ok(())
    }

    fn manage_github_push(&mut self) -> Result<()> {
        let mut github_push_settings = crate::github_push_settings::GithubPushSettings::new(self.config_path.clone())?;
        github_push_settings.run()
    }

    fn manage_push(&mut self, push_name: &str) -> Result<()> {
        loop {
            self.term.clear_screen()?;
            self.term.write_line(&format!("{} 推送管理", push_name))?;
            
            // 显示当前设置
            let current_config = self.config.push.as_ref()
                .and_then(|configs| {
                    configs.iter().find(|c| c.push_name == push_name)
                });

            if let Some(config) = current_config {
                self.term.write_line("当前设置：")?;
                match push_name {
                    "Telegram" => {
                        if let Some(token) = &config.telegram_bot_token {
                            self.term.write_line(&format!("Bot Token：{}", token))?;
                        }
                        if let Some(user_id) = &config.telegram_user_id {
                            self.term.write_line(&format!("User ID：{}", user_id))?;
                        }
                    },
                    "PushPlus" => {
                        if let Some(token) = &config.pushplus_token {
                            self.term.write_line(&format!("Token：{}", token))?;
                        }
                    },
                    "Server酱" => {
                        if let Some(sendkey) = &config.server_sendkey {
                            self.term.write_line(&format!("SendKey：{}", sendkey))?;
                        }
                    },
                    "PushDeer" => {
                        if let Some(pushkey) = &config.pushdeer_pushkey {
                            self.term.write_line(&format!("PushKey：{}", pushkey))?;
                        }
                    },
                    "企业微信" => {
                        if let Some(corpid) = &config.wechat_corpid {
                            self.term.write_line(&format!("企业ID：{}", corpid))?;
                        }
                        if let Some(secret) = &config.wechat_secret {
                            self.term.write_line(&format!("应用Secret：{}", secret))?;
                        }
                        if let Some(agentid) = &config.wechat_agentid {
                            self.term.write_line(&format!("应用ID：{}", agentid))?;
                        }
                        if let Some(userid) = &config.wechat_userid {
                            self.term.write_line(&format!("接收者ID：{}", userid))?;
                        }
                    },
                    "Synology-Chat" => {
                        if let Some(url) = &config.synology_chat_url {
                            self.term.write_line(&format!("Webhook URL：{}", url))?;
                        }
                    },
                    _ => {}
                }
            } else {
                self.term.write_line("当前没有设置任何参数")?;
            }

            let items = [
                "设置/修改参数",
                "删除推送",
                "返回上级",
            ];

            let selection = Select::with_theme(&self.theme)
                .with_prompt("请选择操作（按ESC返回上级）")
                .items(&items)
                .default(0)
                .interact_opt()?;

            // 如果用户按ESC返回，则直接返回
            let selection = match selection {
                Some(value) => value,
                None => return Ok(()),
            };

            match selection {
                0 => {
                    if current_config.is_some() {
                        self.configure_push(push_name, true)?;
                    } else {
                        self.configure_push(push_name, false)?;
                    }
                },
                1 => {
                    if current_config.is_some() {
                        self.delete_push(push_name)?;
                    } else {
                        self.term.write_line(&format!("{} 未设置", push_name))?;
                        self.term.read_line()?;
                    }
                },
                2 => break,
                _ => unreachable!(),
            }
        }
        Ok(())
    }

    fn configure_push(&mut self, push_name: &str, is_modify: bool) -> Result<()> {
        if is_modify {
            self.term.write_line(&format!("正在修改 {} 推送...", push_name))?;
        } else {
            self.term.write_line(&format!("正在设置 {} 推送...", push_name))?;
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
                let token: String = Input::with_theme(&self.theme)
                    .with_prompt("请输入 telegram_bot_token")
                    .interact_text()?;
                new_config.telegram_bot_token = Some(token);

                let user_id: String = Input::with_theme(&self.theme)
                    .with_prompt("请输入 telegram_user_id")
                    .interact_text()?;
                new_config.telegram_user_id = Some(user_id);
            },
            "PushPlus" => {
                let token: String = Input::with_theme(&self.theme)
                    .with_prompt("请输入 pushplus_token")
                    .interact_text()?;
                new_config.pushplus_token = Some(token);
            },
            "Server酱" => {
                let sendkey: String = Input::with_theme(&self.theme)
                    .with_prompt("请输入 server_sendkey")
                    .interact_text()?;
                new_config.server_sendkey = Some(sendkey);
            },
            "PushDeer" => {
                let pushkey: String = Input::with_theme(&self.theme)
                    .with_prompt("请输入 pushdeer_pushkey")
                    .interact_text()?;
                new_config.pushdeer_pushkey = Some(pushkey);
            },
            "企业微信" => {
                let corpid: String = Input::with_theme(&self.theme)
                    .with_prompt("请输入 企业ID (wechat_corpid)")
                    .interact_text()?;
                new_config.wechat_corpid = Some(corpid);

                let secret: String = Input::with_theme(&self.theme)
                    .with_prompt("请输入 应用Secret (wechat_secret)")
                    .interact_text()?;
                new_config.wechat_secret = Some(secret);

                let agentid: String = Input::with_theme(&self.theme)
                    .with_prompt("请输入 应用ID (wechat_agentid)")
                    .interact_text()?;
                new_config.wechat_agentid = Some(agentid);

                let userid: String = Input::with_theme(&self.theme)
                    .with_prompt("请输入 接收者ID (wechat_userid)")
                    .interact_text()?;
                new_config.wechat_userid = Some(userid);
            },
            "Synology-Chat" => {
                let url: String = Input::with_theme(&self.theme)
                    .with_prompt("请输入 Webhook URL (synology_chat_url)")
                    .interact_text()?;
                new_config.synology_chat_url = Some(url);
            },
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
        self.term.write_line(&format!("{} 参数已设置完成！", push_name))?;
        self.term.read_line()?;
        Ok(())
    }

    fn delete_push(&mut self, push_name: &str) -> Result<()> {
        self.term.write_line(&format!("确认删除 {} 的推送设置吗？", push_name))?;
        
        let items = ["是", "否"];
        let selection = Select::with_theme(&self.theme)
            .with_prompt("确认删除推送设置吗？（按ESC返回上级）")
            .items(&items)
            .default(1)
            .interact_opt()?;

        // 如果用户按ESC返回，则直接返回
        let selection = match selection {
            Some(value) => value,
            None => return Ok(()),
        };

        if selection == 0 {
            if let Some(push_configs) = &mut self.config.push {
                push_configs.retain(|c| c.push_name != push_name);
                
                // 如果没有剩余的推送设置，删除 push 键
                if push_configs.is_empty() {
                    self.config.push = None;
                }
                
                self.config.save(&self.config_path)?;
                self.term.write_line(&format!("{} 的推送设置已删除", push_name))?;
            }
        } else {
            self.term.write_line("取消删除操作")?;
        }
        
        self.term.read_line()?;
        Ok(())
    }
}