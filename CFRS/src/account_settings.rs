use anyhow::Result;
use dialoguer::{theme::ColorfulTheme, Select, Input};
use regex::Regex;
use std::path::PathBuf;
use console::Term;
use crate::{Config, Account, clear_screen, Settings, impl_settings};

pub struct AccountSettings {
    config_path: PathBuf,
    config: Config,
    theme: ColorfulTheme,
    email_regex: Regex,
    term: Term,
}

impl AccountSettings {
    pub fn new(config_path: PathBuf) -> Result<Self> {
        let mut settings = AccountSettings {
            config_path: config_path.clone(),
            config: Config::default(),
            theme: ColorfulTheme::default(),
            email_regex: Regex::new(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$").unwrap(),
            term: Term::stdout(),
        };
        settings.load_config()?;
        Ok(settings)
    }

    pub fn run(&mut self) -> Result<()> {
        loop {
            clear_screen()?;
            self.list_accounts()?;

            let items = [
                "添加账户",
                "删除账户",
                "修改账户",
            ];

            let selection = Select::with_theme(&self.theme)
                .with_prompt("账户设置（按ESC返回上级）")
                .items(&items)
                .default(0)
                .interact_opt()?;

            // 如果用户按ESC返回，则直接返回
            let selection = match selection {
                Some(value) => value,
                None => return Ok(()),
            };

            match selection {
                0 => self.add_account()?,
                1 => self.delete_account()?,
                2 => self.modify_account()?,
                _ => unreachable!(),
            }
        }
    }

    fn list_accounts(&self) -> Result<()> {
        if self.config.account.is_empty() {
            self.term.write_line("(暂未设置账户组)")?;
        } else {
            let account_info = self.config.account
                .iter()
                .map(|acc| format!(
                    "- 账户组: {}\n  邮箱: {}\n  区域ID: {}\n  API Key: {}",
                    acc.account_name, acc.x_email, acc.zone_id, acc.api_key
                ))
                .collect::<Vec<String>>()
                .join("\n");
            self.term.write_line(&account_info)?;
            self.term.write_line("")?;
        }
        Ok(())
    }

    fn get_account_input(&mut self, default_values: Option<&Account>) -> Result<Option<Account>> {
        clear_screen()?;

        // 输入账户组名称
        let account_name: String = if let Some(defaults) = default_values {
            Input::with_theme(&self.theme)
                .with_prompt("请输入新的账户组名称")
                .default(defaults.account_name.clone())
                .interact_text()?
        } else {
            let name: String = Input::with_theme(&self.theme)
                .with_prompt("请输入自定义账户组名称（留空返回上级）")
                .allow_empty(true)
                .interact_text()?;
            if name.trim().is_empty() {
                return Ok(None);
            }
            if name == "0" {
                self.term.write_line("账户组名称不能设置为0")?;
                self.term.read_line()?;
                return Ok(None);
            }
            if !name.chars().all(|c| c.is_ascii_alphanumeric() || c == '_') {
                self.term.write_line("只能包含字母、数字和下划线")?;
                self.term.read_line()?;
                return Ok(None);
            }
            if self.config.account.iter().any(|a| a.account_name == name) {
                self.term.write_line("已有该账户组名称！")?;
                self.term.read_line()?;
                return Ok(None);
            }
            name
        };

        let x_email: String = loop {
            let default_email = default_values.map(|d| d.x_email.as_str()).unwrap_or("");
            let email: String = Input::with_theme(&self.theme)
                .with_prompt("请输入账户登陆邮箱")
                .default(default_email.to_string())
                .interact_text()?;
            if self.email_regex.is_match(&email) {
                break email;
            }
            self.term.write_line("邮箱格式不正确")?;
            self.term.read_line()?;
        };

        let zone_id: String = loop {
            let default_zone_id = default_values.map(|d| d.zone_id.as_str()).unwrap_or("");
            let zid: String = Input::with_theme(&self.theme)
                .with_prompt("请输入区域ID")
                .default(default_zone_id.to_string())
                .interact_text()?;
            if zid.trim().is_empty() && default_values.is_none() {
                self.term.write_line("区域ID不能为空")?;
                continue;
            }
            break zid;
        };

        let api_key: String = loop {
            let default_api_key = default_values.map(|d| d.api_key.as_str()).unwrap_or("");
            let key: String = Input::with_theme(&self.theme)
                .with_prompt("请输入API Key")
                .default(default_api_key.to_string())
                .interact_text()?;
            if key.trim().is_empty() && default_values.is_none() {
                self.term.write_line("API Key不能为空")?;
                continue;
            }
            break key;
        };

        Ok(Some(Account {
            account_name,
            x_email,
            zone_id,
            api_key,
        }))
    }

    fn add_account(&mut self) -> Result<()> {
        let account = match self.get_account_input(None)? {
            Some(acc) => acc,
            None => return Ok(()),
        };

        self.config.account.push(account);

        self.config.save(&self.config_path)?;
        self.term.write_line("账户添加成功！")?;
        self.term.read_line()?;
        clear_screen()?;
        Ok(())
    }
    fn delete_account(&mut self) -> Result<()> {
        if self.config.account.is_empty() {
            self.term.write_line("没有可删除的账户！")?;
            self.term.read_line()?;
            return Ok(());
        }

        self.term.write_line("删除账户")?;

        let account_names: Vec<&str> = self.config.account
            .iter()
            .map(|a| a.account_name.as_str())
            .collect();

        let selection = Select::with_theme(&self.theme)
            .with_prompt("选择要删除的账户（按ESC返回上级）")
            .items(&account_names)
            .default(0)
            .interact_opt()?;

        // 如果用户按ESC返回，则直接返回
        let selection = match selection {
            Some(value) => value,
            None => return Ok(()),
        };

        let confirm = Select::with_theme(&self.theme)
            .with_prompt(&format!("确定要删除账户 '{}' 吗？（按ESC返回上级）", account_names[selection]))
            .items(&["是", "否"])
            .default(1)
            .interact_opt()?;

        // 如果用户按ESC返回，则直接返回
        let confirm = match confirm {
            Some(value) => value,
            None => return Ok(()),
        };

        if confirm == 0 {
            self.config.account.remove(selection);
            self.config.save(&self.config_path)?;
            self.term.write_line("账户删除成功！")?;
        } else {
            self.term.write_line("已取消删除操作。")?;
        }

        self.term.read_line()?;
        Ok(())
    }

    fn modify_account(&mut self) -> Result<()> {
        if self.config.account.is_empty() {
            self.term.write_line("没有可修改的账户！")?;
            self.term.read_line()?;
            return Ok(());
        }

        self.term.write_line("修改账户")?;

        let account_names: Vec<&str> = self.config.account
            .iter()
            .map(|a| a.account_name.as_str())
            .collect();

        let selection = Select::with_theme(&self.theme)
            .with_prompt("选择要修改的账户（按ESC返回上级）")
            .items(&account_names)
            .default(0)
            .interact_opt()?;

        // 如果用户按ESC返回，则直接返回
        let selection = match selection {
            Some(value) => value,
            None => return Ok(()),
        };

        let current = self.config.account[selection].clone();

        self.term.write_line("当前账户信息：")?;
        self.term.write_line(&format!("账户组: {}", current.account_name))?;
        self.term.write_line(&format!("邮箱: {}", current.x_email))?;
        self.term.write_line(&format!("区域ID: {}", current.zone_id))?;
        self.term.write_line(&format!("API Key: {}", current.api_key))?;
        self.term.write_line("")?;
        clear_screen()?;

        let account = match self.get_account_input(Some(&current))? {
            Some(acc) => acc,
            None => return Ok(()),
        };

        // 检查账户组名称是否已存在
        if account.account_name != current.account_name {
            if self.config.account.iter().any(|a| a.account_name == account.account_name) {
                self.term.write_line("已有该账户组名称！")?;
                self.term.read_line()?;
                return Ok(());
            }
        }

        // 保存新的账户组名称
        let new_account_name = account.account_name;
        
        let account_ref = &mut self.config.account[selection];
        account_ref.account_name = new_account_name.clone();
        account_ref.x_email = account.x_email;
        account_ref.zone_id = account.zone_id;
        account_ref.api_key = account.api_key;

        // 如果账户组名称已更改，则更新所有相关的解析组
        if new_account_name != current.account_name {
            if let Some(resolves) = &mut self.config.resolve {
                for resolve in resolves {
                    if resolve.add_ddns == current.account_name {
                        resolve.add_ddns = new_account_name.clone();
                    }
                }
            }
        }

        self.config.save(&self.config_path)?;
        self.term.write_line("账户修改成功！")?;
        self.term.read_key()?;
        Ok(())
    }
}

impl_settings!(AccountSettings);