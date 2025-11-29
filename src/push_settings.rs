use crate::ui_components::UIComponents;
use crate::{Config, PushConfig, Settings, clear_screen, impl_settings};
use anyhow::Result;
use std::path::{Path, PathBuf};

// 独立函数，用于获取推送配置
pub fn get_push_config(
    ui: &UIComponents,
    name: &str,
    current: Option<&PushConfig>,
) -> Result<PushConfig> {
    use PushConfig as P;
    Ok(match name {
        "Telegram" => P {
            push_name: name.into(),
            telegram_bot_token: Some(
                ui.get_non_empty_input_with_default(
                    "请输入 TELEGRAM_BOT_TOKEN",
                    current
                        .and_then(|c| c.telegram_bot_token.as_deref())
                        .unwrap_or(""),
                )?,
            ),
            telegram_user_id: Some(
                ui.get_non_empty_input_with_default(
                    "请输入 TELEGRAM_USER_ID",
                    current
                        .and_then(|c| c.telegram_user_id.as_deref())
                        .unwrap_or(""),
                )?,
            ),
            ..Default::default()
        },
        "PushPlus" => P {
            push_name: name.into(),
            pushplus_token: Some(
                ui.get_non_empty_input_with_default(
                    "请输入 PUSHPLUS_TOKEN",
                    current
                        .and_then(|c| c.pushplus_token.as_deref())
                        .unwrap_or(""),
                )?,
            ),
            ..Default::default()
        },
        "Server酱" => P {
            push_name: name.into(),
            server_sendkey: Some(
                ui.get_non_empty_input_with_default(
                    "请输入 SERVER_SENDKEY",
                    current
                        .and_then(|c| c.server_sendkey.as_deref())
                        .unwrap_or(""),
                )?,
            ),
            ..Default::default()
        },
        "PushDeer" => P {
            push_name: name.into(),
            pushdeer_pushkey: Some(
                ui.get_non_empty_input_with_default(
                    "请输入 PUSHDEER_PUSHKEY",
                    current
                        .and_then(|c| c.pushdeer_pushkey.as_deref())
                        .unwrap_or(""),
                )?,
            ),
            ..Default::default()
        },
        "企业微信" => P {
            push_name: name.into(),
            wechat_corpid: Some(
                ui.get_non_empty_input_with_default(
                    "请输入 企业ID (WECHAT_CORPID)",
                    current
                        .and_then(|c| c.wechat_corpid.as_deref())
                        .unwrap_or(""),
                )?,
            ),
            wechat_secret: Some(
                ui.get_non_empty_input_with_default(
                    "请输入 应用Secret (WECHAT_SECRET)",
                    current
                        .and_then(|c| c.wechat_secret.as_deref())
                        .unwrap_or(""),
                )?,
            ),
            wechat_agentid: Some(
                ui.get_non_empty_input_with_default(
                    "请输入 应用ID (WECHAT_AGENTID)",
                    current
                        .and_then(|c| c.wechat_agentid.as_deref())
                        .unwrap_or(""),
                )?,
            ),
            wechat_userid: Some(
                ui.get_non_empty_input_with_default(
                    "请输入 接收者ID (WECHAT_USERID)",
                    current
                        .and_then(|c| c.wechat_userid.as_deref())
                        .unwrap_or(""),
                )?,
            ),
            ..Default::default()
        },
        "Synology-Chat" => P {
            push_name: name.into(),
            synology_chat_url: Some(
                ui.get_url_input_with_default(
                    "请输入 Webhook URL (synology_chat_url)",
                    false,
                    current
                        .and_then(|c| c.synology_chat_url.as_deref())
                        .unwrap_or(""),
                )?,
            ),
            ..Default::default()
        },
        _ => P {
            push_name: name.into(),
            ..Default::default()
        },
    })
}

pub struct PushSettings {
    config_path: PathBuf,
    config: Config,
    ui: UIComponents,
}

impl PushSettings {
    pub fn new(config_path: &Path) -> Result<Self> {
        let mut s = Self {
            config_path: config_path.to_path_buf(),
            config: Config::default(),
            ui: UIComponents::new(),
        };
        s.load_config()?;
        Ok(s)
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

            match self.ui.show_menu("推送管理（按ESC返回上级）", &items, 0)? {
                Some(i) if i < items.len() - 1 => self.manage_push(items[i])?,
                Some(_) => self.manage_github_push()?,
                None => return Ok(()),
            }
        }
    }

    fn list_push_configs(&self) -> Result<()> {
        match &self.config.push {
            Some(cfgs) => {
                let infos: Vec<_> = cfgs.iter().map(Self::format_push_info).collect();
                self.ui.show_info_list("", &infos)?;
            }
            None => {
                self.ui.show_message("当前没有设置任何推送配置")?;
                self.ui.show_message("")?;
            }
        }
        Ok(())
    }

    fn format_push_info(c: &PushConfig) -> String {
        let mut s = format!("- 推送类型: {}\n", c.push_name);
        macro_rules! add {
            ($opt:expr, $label:literal) => {
                if let Some(v) = &$opt {
                    s.push_str(&format!("  {}: {}\n", $label, v));
                }
            };
        }
        add!(c.telegram_bot_token, "Bot Token");
        add!(c.telegram_user_id, "User ID");
        add!(c.pushplus_token, "Token");
        add!(c.server_sendkey, "SendKey");
        add!(c.pushdeer_pushkey, "PushKey");
        add!(c.wechat_corpid, "企业ID");
        add!(c.wechat_secret, "应用Secret");
        add!(c.wechat_agentid, "应用ID");
        add!(c.wechat_userid, "接收者ID");
        add!(c.synology_chat_url, "Webhook URL");
        s
    }

    fn manage_github_push(&mut self) -> Result<()> {
        crate::github_push_settings::GithubPushSettings::new(&self.config_path)?.run()
    }

    fn manage_push(&mut self, push_name: &str) -> Result<()> {
        loop {
            clear_screen()?;
            self.ui.show_message(&format!("{} 推送管理", push_name))?;

            let current = self
                .config
                .push
                .as_ref()
                .and_then(|v| v.iter().find(|c| c.push_name == push_name));

            if let Some(cfg) = current {
                self.ui.show_message("当前设置：")?;
                self.ui.show_message(&Self::format_push_info(cfg))?;
            } else {
                self.ui.show_message("当前没有设置任何参数")?;
            }

            let menu = ["设置/修改参数", "删除推送"];
            match self.ui.show_menu("请选择操作（按ESC返回上级）", &menu, 0)? {
                Some(0) => {
                    let new_cfg = get_push_config(&self.ui, push_name, current)?;
                    self.save_push_config(push_name, new_cfg, current.is_some())?;
                }
                Some(1) => {
                    if current.is_some() {
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

    fn save_push_config(&mut self, name: &str, cfg: PushConfig, modify: bool) -> Result<()> {
        let cfg = cfg.compact();
        let list = self.config.push.get_or_insert_with(Vec::new);
        if modify {
            if let Some(pos) = list.iter().position(|c| c.push_name == name) {
                list[pos] = cfg.merge_with(&list[pos]).compact();
            }
        } else {
            list.push(cfg);
        }
        self.config.save(self.config_path.as_path())?;
        self.ui
            .show_success(&format!("{} 参数已设置完成！", name))?;
        Ok(())
    }

    fn delete_push(&mut self, name: &str) -> Result<()> {
        let items = ["是", "否"];
        match self
            .ui
            .show_menu(&format!("确认删除 {} 的推送设置吗？", name), &items, 1)?
        {
            Some(0) => {
                if let Some(v) = &mut self.config.push {
                    v.retain(|c| c.push_name != name);
                    if v.is_empty() {
                        self.config.push = None;
                    }
                    self.config.save(self.config_path.as_path())?;
                    self.ui
                        .show_success(&format!("{} 的推送设置已删除", name))?;
                }
            }
            _ => {
                self.ui.show_message("取消删除操作")?;
                self.ui.pause("")?;
            }
        }
        Ok(())
    }
}

impl PushConfig {
    fn merge_with(&self, other: &Self) -> Self {
        macro_rules! or {
            ($f:ident) => {
                self.$f.clone().or_else(|| other.$f.clone())
            };
        }
        Self {
            push_name: self.push_name.clone(),
            telegram_bot_token: or!(telegram_bot_token),
            telegram_user_id: or!(telegram_user_id),
            pushplus_token: or!(pushplus_token),
            server_sendkey: or!(server_sendkey),
            pushdeer_pushkey: or!(pushdeer_pushkey),
            wechat_corpid: or!(wechat_corpid),
            wechat_secret: or!(wechat_secret),
            wechat_agentid: or!(wechat_agentid),
            wechat_userid: or!(wechat_userid),
            synology_chat_url: or!(synology_chat_url),
        }
    }

    fn compact(&self) -> Self {
        let mut r = PushConfig {
            push_name: self.push_name.clone(),
            ..Default::default()
        };
        macro_rules! keep {
            ($f:ident) => {
                if let Some(v) = &self.$f {
                    r.$f = Some(v.clone());
                }
            };
        }
        keep!(telegram_bot_token);
        keep!(telegram_user_id);
        keep!(pushplus_token);
        keep!(server_sendkey);
        keep!(pushdeer_pushkey);
        keep!(wechat_corpid);
        keep!(wechat_secret);
        keep!(wechat_agentid);
        keep!(wechat_userid);
        keep!(synology_chat_url);
        r
    }
}

impl_settings!(PushSettings);